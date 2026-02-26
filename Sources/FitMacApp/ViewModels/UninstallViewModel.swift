import Foundation
import FitMacCore
import Combine

@MainActor
final class UninstallViewModel: ObservableObject {
    @Published var installedApps: [AppInfo] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedApp: AppInfo?
    @Published var foundLeftovers: [CleanupItem] = []
    @Published var isScanningLeftovers = false
    @Published var errorMessage: String?
    
    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var totalLeftoverSize: Int64 {
        foundLeftovers.reduce(0) { $0 + $1.size }
    }
    
    func loadInstalledApps() async {
        isLoading = true
        defer { isLoading = false }
        
        var apps: [AppInfo] = []
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
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                
                if let appInfo = parseAppBundle(at: fileURL) {
                    apps.append(appInfo)
                }
                
                enumerator.skipDescendants()
            }
        }
        
        installedApps = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    func scanLeftovers(for app: AppInfo) async {
        isScanningLeftovers = true
        foundLeftovers = []
        
        let searchPaths = AppLeftoverPaths.searchPaths(for: app.bundleIdentifier)
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    let isDirectory = try FileUtils.isDirectory(at: path)
                    let size = try FileUtils.sizeOfItem(at: path)
                    let modifiedDate = try? FileUtils.modifiedDate(at: path)
                    
                    foundLeftovers.append(CleanupItem(
                        path: path,
                        category: .appCache,
                        size: size,
                        isDirectory: isDirectory,
                        modifiedDate: modifiedDate
                    ))
                } catch {
                    continue
                }
            }
        }
        
        isScanningLeftovers = false
    }
    
    func deleteLeftovers() -> Bool {
        var success = true
        let deletedItems = foundLeftovers
        
        for item in foundLeftovers {
            do {
                _ = try FileUtils.moveToTrash(at: item.path)
            } catch {
                errorMessage = "Failed to delete \(item.path.lastPathComponent): \(error.localizedDescription)"
                success = false
            }
        }
        
        if success {
            let log = CleanupLog(
                operation: "App Leftover Cleanup",
                itemsDeleted: deletedItems.count,
                freedSpace: totalLeftoverSize,
                details: deletedItems.map { $0.path.path }
            )
            Task { try? await CleanupLogger.shared.log(log) }
            foundLeftovers = []
        }
        return success
    }
    
    private func parseAppBundle(at url: URL) -> AppInfo? {
        let plistPath = url.appendingPathComponent("Contents/Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              let name = plist["CFBundleName"] as? String ?? plist["CFBundleDisplayName"] as? String else {
            return nil
        }
        
        let version = plist["CFBundleShortVersionString"] as? String
        let size = try? FileUtils.sizeOfItem(at: url)
        
        return AppInfo(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: url,
            version: version,
            size: size
        )
    }
}
