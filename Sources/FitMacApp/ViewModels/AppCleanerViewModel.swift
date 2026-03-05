import Foundation
import FitMacCore
import Combine

@MainActor
final class AppCleanerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var orphanLeftovers: [AppLeftover] = []
    @Published var installedAppData: [AppLeftover] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var cleanupResult: CleanupResult?
    
    var totalSelectedSize: Int64 {
        (orphanLeftovers + installedAppData)
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scan() {
        Task {
            await performScan()
        }
    }
    
    private func performScan() async {
        isScanning = true
        errorMessage = nil
        orphanLeftovers = []
        installedAppData = []
        selectedItems = []
        
        var installedBundleIds = Set<String>()
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        for directory in appDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension == "app" else { continue }
                
                if let bundleId = extractBundleIdentifier(from: fileURL) {
                    installedBundleIds.insert(bundleId)
                }
                
                enumerator.skipDescendants()
            }
        }
        
        var foundOrphans: [AppLeftover] = []
        var foundInstalled: [AppLeftover] = []
        
        let leftoverPaths = getLeftoverSearchPaths()
        
        for (bundleId, paths) in leftoverPaths {
            var existingPaths: [URL] = []
            var totalSize: Int64 = 0
            
            for path in paths {
                guard FileManager.default.fileExists(atPath: path.path) else { continue }
                
                do {
                    let size = try FileUtils.sizeOfItem(at: path)
                    existingPaths.append(path)
                    totalSize += size
                } catch {
                    continue
                }
            }
            
            guard totalSize > 0 else { continue }
            
            let appName = extractAppName(from: bundleId)
            let isInstalled = installedBundleIds.contains(bundleId)
            
            let leftover = AppLeftover(
                bundleId: bundleId,
                appName: appName,
                paths: existingPaths,
                size: totalSize,
                isInstalled: isInstalled
            )
            
            if isInstalled {
                foundInstalled.append(leftover)
            } else {
                foundOrphans.append(leftover)
            }
        }
        
        orphanLeftovers = foundOrphans.sorted { $0.size > $1.size }
        installedAppData = foundInstalled.sorted { $0.size > $1.size }
        
        isScanning = false
    }
    
    private func getLeftoverSearchPaths() -> [String: [URL]] {
        var result: [String: [URL]] = [:]
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        
        let searchDirectories = [
            "Preferences",
            "Application Support",
            "Caches",
            "Containers",
            "Logs",
            "Saved Application State",
            "WebKit",
            "Cookies",
            "HTTPStorages",
            "Group Containers"
        ]
        
        for dir in searchDirectories {
            let dirPath = library.appendingPathComponent(dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dirPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for item in contents {
                let name = item.lastPathComponent
                guard looksLikeBundleId(name) else { continue }
                
                let bundleId = name
                    .replacingOccurrences(of: ".plist", with: "")
                    .replacingOccurrences(of: ".savedState", with: "")
                
                if result[bundleId] == nil {
                    result[bundleId] = []
                }
                result[bundleId]?.append(item)
            }
        }
        
        return result
    }
    
    private func looksLikeBundleId(_ name: String) -> Bool {
        let cleanName = name
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".savedState", with: "")
        
        return cleanName.contains(".") && cleanName.count > 5
    }
    
    private func extractBundleIdentifier(from appURL: URL) -> String? {
        let plistPath = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleId
    }
    
    private func extractAppName(from bundleId: String) -> String {
        if let lastComponent = bundleId.components(separatedBy: ".").last {
            return lastComponent
        }
        return bundleId
    }
    
    func selectAll() {
        selectedItems = Set((orphanLeftovers + installedAppData).map(\.id))
    }
    
    func selectOrphans() {
        selectedItems = Set(orphanLeftovers.map(\.id))
    }
    
    func selectInstalled() {
        selectedItems = Set(installedAppData.map(\.id))
    }
    
    func deselectAll() {
        selectedItems = []
    }
    
    func clean(dryRun: Bool) async {
        let allItems = orphanLeftovers + installedAppData
        let itemsToClean = allItems.filter { selectedItems.contains($0.id) }
        
        guard !itemsToClean.isEmpty else { return }
        
        var deletedItems: [CleanupItem] = []
        var failedItems: [(CleanupItem, String)] = []
        var totalFreed: Int64 = 0
        
        for leftover in itemsToClean {
            for path in leftover.paths {
                do {
                    if !dryRun {
                        _ = try FileUtils.moveToTrash(at: path)
                    }
                    let item = CleanupItem(
                        path: path,
                        category: .appCache,
                        size: try FileUtils.sizeOfItem(at: path),
                        isDirectory: try FileUtils.isDirectory(at: path)
                    )
                    deletedItems.append(item)
                    totalFreed += item.size
                } catch {
                    let item = CleanupItem(
                        path: path,
                        category: .appCache,
                        size: 0,
                        isDirectory: false
                    )
                    failedItems.append((item, error.localizedDescription))
                }
            }
        }
        
        cleanupResult = CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: totalFreed
        )
        
        if !dryRun, cleanupResult != nil {
            let log = CleanupLog(
                operation: "App Leftover Cleanup",
                itemsDeleted: deletedItems.count,
                freedSpace: totalFreed,
                details: deletedItems.map { $0.path.path }
            )
            try? await CleanupLogger.shared.log(log)
            
            await performScan()
        }
    }
}

struct AppLeftover: Identifiable, Hashable {
    let id: UUID
    let bundleId: String
    let appName: String
    let paths: [URL]
    let size: Int64
    let isInstalled: Bool
    
    init(bundleId: String, appName: String, paths: [URL], size: Int64, isInstalled: Bool) {
        self.id = UUID()
        self.bundleId = bundleId
        self.appName = appName
        self.paths = paths
        self.size = size
        self.isInstalled = isInstalled
    }
    
    static func == (lhs: AppLeftover, rhs: AppLeftover) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
