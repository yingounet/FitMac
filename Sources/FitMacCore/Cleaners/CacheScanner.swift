import Foundation

public actor CacheScanner {
    public init() {}
    
    public func scan(categories: [CacheCategory] = CacheCategory.allCases) async throws -> ScanResult {
        var items: [CleanupItem] = []
        
        let pathsToScan = CachePaths.allCachePaths.filter { categories.contains($1) }
        
        for (pathString, category) in pathsToScan {
            if pathString.contains("*") {
                let expandedUrls = CachePaths.expandWildcardPath(pathString)
                for url in expandedUrls {
                    if let item = try? await scanItem(at: url, category: category, isBrowserCache: category == .browserCache) {
                        items.append(item)
                    }
                }
            } else {
                let url = CachePaths.expandedPath(pathString)
                
                if let item = try? await scanItem(at: url, category: category, isBrowserCache: category == .browserCache) {
                    items.append(item)
                }
            }
        }
        
        return ScanResult(items: items)
    }
    
    public func scanCategory(_ category: CacheCategory) async throws -> ScanResult {
        try await scan(categories: [category])
    }
    
    private func scanItem(at url: URL, category: CacheCategory, isBrowserCache: Bool = false) async throws -> CleanupItem? {
        let fileManager = FileManager.default
        
        guard fileManager.isReadableFile(atPath: url.path),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        if isBrowserCache {
            let safeItems = await scanBrowserCacheSafely(at: url, category: category)
            if !safeItems.isEmpty {
                let totalSize = safeItems.reduce(0) { $0 + $1.size }
                return CleanupItem(
                    path: url,
                    category: category,
                    size: totalSize,
                    isDirectory: true,
                    modifiedDate: try? FileUtils.modifiedDate(at: url),
                    subItems: safeItems
                )
            }
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
    
    private func scanBrowserCacheSafely(at url: URL, category: CacheCategory) async -> [CleanupItem] {
        let fileManager = FileManager.default
        var safeItems: [CleanupItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return safeItems
        }
        
        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            
            if CachePaths.isProtectedBrowserFile(path) {
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                
                if resourceValues.isDirectory == true {
                    continue
                }
                
                if let fileSize = resourceValues.fileSize, fileSize > 0 {
                    safeItems.append(CleanupItem(
                        path: fileURL,
                        category: category,
                        size: Int64(fileSize),
                        isDirectory: false,
                        modifiedDate: resourceValues.contentModificationDate
                    ))
                }
            } catch {
                continue
            }
        }
        
        return safeItems
    }
}

public actor CacheCleaner {
    private let baseCleaner = BaseCleaner<CleanupItem>()
    
    public init() {}
    
    public func clean(items: [CleanupItem], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            if dryRun {
                deletedItems.append(item)
                freedSpace += item.size
            } else {
                if let subItems = item.subItems, !subItems.isEmpty {
                    for subItem in subItems {
                        do {
                            _ = try FileUtils.moveToTrash(at: subItem.path)
                            deletedItems.append(subItem)
                            freedSpace += subItem.size
                        } catch {
                            failedItems.append(FailedItem(item: subItem, error: error.localizedDescription))
                        }
                    }
                } else {
                    do {
                        _ = try FileUtils.moveToTrash(at: item.path)
                        deletedItems.append(item)
                        freedSpace += item.size
                    } catch {
                        failedItems.append(FailedItem(item: item, error: error.localizedDescription))
                    }
                }
            }
        }
        
        return CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: freedSpace
        )
    }
}
