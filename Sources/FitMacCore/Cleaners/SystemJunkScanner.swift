import Foundation

public enum SystemJunkCategory: String, CaseIterable, Codable {
    case temporaryFiles = "Temporary Files"
    case brokenDownloads = "Broken Downloads"
    case documentVersions = "Document Versions"
    case systemLeftovers = "System Leftovers"
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .temporaryFiles: return "doc.text.fill"
        case .brokenDownloads: return "arrow.down.circle.fill"
        case .documentVersions: return "doc.on.doc.fill"
        case .systemLeftovers: return "gearshape.fill"
        }
    }
}

public struct SystemJunkItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let path: URL
    public let category: SystemJunkCategory
    public let size: Int64
    public let isDirectory: Bool
    public let description: String?
    public let modifiedDate: Date?
    
    public init(path: URL, category: SystemJunkCategory, size: Int64, isDirectory: Bool, description: String? = nil, modifiedDate: Date? = nil) {
        self.id = UUID()
        self.path = path
        self.category = category
        self.size = size
        self.isDirectory = isDirectory
        self.description = description
        self.modifiedDate = modifiedDate
    }
}

public struct SystemJunkScanResult: Codable {
    public let items: [SystemJunkItem]
    public let totalSize: Int64
    public let scanDate: Date
    public let categories: [SystemJunkCategory: Int64]
    
    public init(items: [SystemJunkItem], scanDate: Date = Date()) {
        self.items = items
        self.scanDate = scanDate
        self.totalSize = items.reduce(0) { $0 + $1.size }
        var cats: [SystemJunkCategory: Int64] = [:]
        for item in items {
            cats[item.category, default: 0] += item.size
        }
        self.categories = cats
    }
    
    public func items(for category: SystemJunkCategory) -> [SystemJunkItem] {
        items.filter { $0.category == category }
    }
}

public actor SystemJunkScanner {
    public init() {}
    
    public func scan() async throws -> SystemJunkScanResult {
        var items: [SystemJunkItem] = []
        
        items.append(contentsOf: await scanTemporaryFiles())
        items.append(contentsOf: await scanBrokenDownloads())
        items.append(contentsOf: await scanDocumentVersions())
        items.append(contentsOf: await scanSystemLeftovers())
        
        return SystemJunkScanResult(items: items)
    }
    
    private func scanTemporaryFiles() async -> [SystemJunkItem] {
        var items: [SystemJunkItem] = []
        let fileManager = FileManager.default
        
        let tempPaths = [
            "~/Library/Caches/com.apple.bird",
            "/tmp",
            "/private/tmp",
            "/var/tmp"
        ]
        
        for pathString in tempPaths {
            let path = pathString.hasPrefix("~") 
                ? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(String(pathString.dropFirst(2)))
                : URL(fileURLWithPath: pathString)
            
            if let item = await scanPath(path, category: .temporaryFiles, description: "Temporary system files") {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func scanBrokenDownloads() async -> [SystemJunkItem] {
        var items: [SystemJunkItem] = []
        let fileManager = FileManager.default
        let downloadsPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        guard let downloadsURL = downloadsPath else { return items }
        
        let brokenExtensions = ["crdownload", "tmp", "download", "part"]
        let potentiallyBrokenExtensions = ["dmg", "pkg", "zip"]
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }
        
        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            
            if brokenExtensions.contains(ext) {
                if let item = await scanFile(fileURL, category: .brokenDownloads, description: "Incomplete download") {
                    items.append(item)
                }
            } else if potentiallyBrokenExtensions.contains(ext) {
                if let item = await checkPotentiallyBrokenFile(fileURL) {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    private func checkPotentiallyBrokenFile(_ url: URL) async -> SystemJunkItem? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard let fileSize = resourceValues.fileSize, fileSize > 0 else { return nil }
            guard let modifiedDate = resourceValues.contentModificationDate else { return nil }
            
            let daysSinceModified = Date().timeIntervalSince(modifiedDate) / 86400
            
            if daysSinceModified > 30 && fileSize < 1024 {
                return SystemJunkItem(
                    path: url,
                    category: .brokenDownloads,
                    size: Int64(fileSize),
                    isDirectory: false,
                    description: "Potentially corrupted or incomplete (small size, old)",
                    modifiedDate: modifiedDate
                )
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func scanDocumentVersions() async -> [SystemJunkItem] {
        var items: [SystemJunkItem] = []
        let fileManager = FileManager.default
        
        let autosavePath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Autosave Information")
        
        if let item = await scanPath(autosavePath, category: .documentVersions, description: "Auto-saved document versions") {
            items.append(item)
        }
        
        return items
    }
    
    private func scanSystemLeftovers() async -> [SystemJunkItem] {
        var items: [SystemJunkItem] = []
        let fileManager = FileManager.default
        
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let searchPaths = [
            homeDir,
            homeDir.appendingPathComponent("Desktop"),
            homeDir.appendingPathComponent("Documents"),
            homeDir.appendingPathComponent("Downloads")
        ]
        
        var dsStoreSize: Int64 = 0
        var dsStoreCount = 0
        
        for searchPath in searchPaths {
            if let dsStoreItems = await findDSStoreFiles(in: searchPath) {
                dsStoreSize += dsStoreItems.0
                dsStoreCount += dsStoreItems.1
            }
        }
        
        if dsStoreCount > 0 {
            items.append(SystemJunkItem(
                path: homeDir,
                category: .systemLeftovers,
                size: dsStoreSize,
                isDirectory: false,
                description: "\(dsStoreCount) .DS_Store files found"
            ))
        }
        
        return items
    }
    
    private func findDSStoreFiles(in directory: URL) async -> (Int64, Int)? {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }
        
        var totalSize: Int64 = 0
        var count = 0
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == ".DS_Store" {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                        count += 1
                    }
                } catch {
                    continue
                }
            }
        }
        
        return count > 0 ? (totalSize, count) : nil
    }
    
    private func scanPath(_ url: URL, category: SystemJunkCategory, description: String?) async -> SystemJunkItem? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let size = try FileUtils.sizeOfItem(at: url)
            guard size > 0 else { return nil }
            
            let isDirectory = try FileUtils.isDirectory(at: url)
            let modifiedDate = try? FileUtils.modifiedDate(at: url)
            
            return SystemJunkItem(
                path: url,
                category: category,
                size: size,
                isDirectory: isDirectory,
                description: description,
                modifiedDate: modifiedDate
            )
        } catch {
            return nil
        }
    }
    
    private func scanFile(_ url: URL, category: SystemJunkCategory, description: String?) async -> SystemJunkItem? {
        let fileManager = FileManager.default
        
        guard fileManager.isReadableFile(atPath: url.path),
              fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
            guard let fileSize = resourceValues.fileSize, fileSize > 0 else { return nil }
            
            return SystemJunkItem(
                path: url,
                category: category,
                size: Int64(fileSize),
                isDirectory: resourceValues.isDirectory ?? false,
                description: description,
                modifiedDate: resourceValues.contentModificationDate
            )
        } catch {
            return nil
        }
    }
}

public actor SystemJunkCleaner {
    public init() {}
    
    public func clean(items: [SystemJunkItem], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            do {
                if dryRun {
                    let cleanupItem = CleanupItem(
                        path: item.path,
                        category: .temporary,
                        size: item.size,
                        isDirectory: item.isDirectory
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                } else {
                    if item.isDirectory {
                        _ = try FileUtils.moveToTrash(at: item.path)
                    } else {
                        _ = try FileUtils.moveToTrash(at: item.path)
                    }
                    let cleanupItem = CleanupItem(
                        path: item.path,
                        category: .temporary,
                        size: item.size,
                        isDirectory: item.isDirectory
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                }
            } catch {
                let cleanupItem = CleanupItem(
                    path: item.path,
                    category: .temporary,
                    size: item.size,
                    isDirectory: item.isDirectory
                )
                failedItems.append(FailedItem(item: cleanupItem, error: error.localizedDescription))
            }
        }
        
        return CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: freedSpace
        )
    }
}
