import Foundation

public actor CacheScanner {
    public init() {}
    
    public func scan(categories: [CacheCategory] = CacheCategory.allCases) async throws -> ScanResult {
        var items: [CleanupItem] = []
        
        let pathsToScan = CachePaths.allCachePaths.filter { categories.contains($1) }
        
        for (pathString, category) in pathsToScan {
            let url = CachePaths.expandedPath(pathString)
            
            if let item = try? await scanItem(at: url, category: category) {
                items.append(item)
            }
        }
        
        return ScanResult(items: items)
    }
    
    public func scanCategory(_ category: CacheCategory) async throws -> ScanResult {
        try await scan(categories: [category])
    }
    
    private func scanItem(at url: URL, category: CacheCategory) async throws -> CleanupItem? {
        let fileManager = FileManager.default
        
        guard fileManager.isReadableFile(atPath: url.path),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let isDirectory: Bool
        let size: Int64
        let modifiedDate: Date?
        
        do {
            isDirectory = try FileUtils.isDirectory(at: url)
        } catch {
            return nil
        }
        
        do {
            size = try FileUtils.sizeOfItem(at: url)
        } catch {
            return nil
        }
        
        modifiedDate = try? FileUtils.modifiedDate(at: url)
        
        return CleanupItem(
            path: url,
            category: category,
            size: size,
            isDirectory: isDirectory,
            modifiedDate: modifiedDate
        )
    }
}

public actor CacheCleaner {
    public init() {}
    
    public func clean(items: [CleanupItem], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            do {
                if dryRun {
                    deletedItems.append(item)
                    freedSpace += item.size
                } else {
                    if item.isDirectory {
                        try FileManager.default.removeItem(at: item.path)
                    } else {
                        _ = try FileUtils.moveToTrash(at: item.path)
                    }
                    deletedItems.append(item)
                    freedSpace += item.size
                }
            } catch {
                failedItems.append(FailedItem(item: item, error: error.localizedDescription))
            }
        }
        
        return CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: freedSpace
        )
    }
}
