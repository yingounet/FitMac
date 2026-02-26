import Foundation

public protocol CleanableItem {
    var cleanablePath: URL { get }
    var cleanableSize: Int64 { get }
    var cleanableIsDirectory: Bool { get }
}

extension CleanupItem: CleanableItem {
    public var cleanablePath: URL { path }
    public var cleanableSize: Int64 { size }
    public var cleanableIsDirectory: Bool { isDirectory }
}

extension LanguageFile: CleanableItem {
    public var cleanablePath: URL { lprojPath }
    public var cleanableSize: Int64 { size }
    public var cleanableIsDirectory: Bool { true }
}

extension iTunesJunkItem: CleanableItem {
    public var cleanablePath: URL { path }
    public var cleanableSize: Int64 { size }
    public var cleanableIsDirectory: Bool { isDirectory }
}

extension MailAttachment: CleanableItem {
    public var cleanablePath: URL { path }
    public var cleanableSize: Int64 { size }
    public var cleanableIsDirectory: Bool { false }
}

public actor BaseCleaner<T: CleanableItem> {
    public init() {}
    
    public func clean(items: [T], dryRun: Bool = true, filter: ((T) -> Bool)? = nil) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            if let filter = filter, !filter(item) {
                continue
            }
            
            let path = item.cleanablePath
            let size = item.cleanableSize
            
            if dryRun {
                let cleanupItem = CleanupItem(
                    path: path,
                    category: .temporary,
                    size: size,
                    isDirectory: item.cleanableIsDirectory
                )
                deletedItems.append(cleanupItem)
                freedSpace += size
            } else {
                do {
                    _ = try FileUtils.moveToTrash(at: path)
                    let cleanupItem = CleanupItem(
                        path: path,
                        category: .temporary,
                        size: size,
                        isDirectory: item.cleanableIsDirectory
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += size
                } catch {
                    let cleanupItem = CleanupItem(
                        path: path,
                        category: .temporary,
                        size: size,
                        isDirectory: item.cleanableIsDirectory
                    )
                    failedItems.append(FailedItem(item: cleanupItem, error: error.localizedDescription))
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
