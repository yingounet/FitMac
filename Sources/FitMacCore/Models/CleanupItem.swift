import Foundation

public enum CacheCategory: String, CaseIterable, Codable {
    case systemCache = "System Cache"
    case appCache = "Application Cache"
    case browserCache = "Browser Cache"
    case devCache = "Developer Cache"
    case logs = "Logs"
    case temporary = "Temporary Files"
    
    public var displayName: String { rawValue }
}

public struct CleanupItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let path: URL
    public let category: CacheCategory
    public var size: Int64
    public let isDirectory: Bool
    public let modifiedDate: Date?
    public let subItems: [CleanupItem]?
    
    public init(
        path: URL,
        category: CacheCategory,
        size: Int64 = 0,
        isDirectory: Bool = false,
        modifiedDate: Date? = nil,
        subItems: [CleanupItem]? = nil
    ) {
        self.id = UUID()
        self.path = path
        self.category = category
        self.size = size
        self.isDirectory = isDirectory
        self.modifiedDate = modifiedDate
        self.subItems = subItems
    }
}

public struct ScanResult: Codable {
    public let items: [CleanupItem]
    public let totalSize: Int64
    public let scanDate: Date
    public let categories: [CacheCategory: Int64]
    
    public init(items: [CleanupItem], scanDate: Date = Date()) {
        self.items = items
        self.scanDate = scanDate
        self.totalSize = items.reduce(0) { $0 + $1.size }
        var cats: [CacheCategory: Int64] = [:]
        for item in items {
            cats[item.category, default: 0] += item.size
        }
        self.categories = cats
    }
    
    public func items(for category: CacheCategory) -> [CleanupItem] {
        items.filter { $0.category == category }
    }
}

public struct FailedItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let item: CleanupItem
    public let error: String
    
    public init(item: CleanupItem, error: String) {
        self.id = UUID()
        self.item = item
        self.error = error
    }
}

public struct CleanupResult: Codable {
    public let deletedItems: [CleanupItem]
    public let failedItems: [FailedItem]
    public let freedSpace: Int64
    public let cleanupDate: Date
    
    public init(
        deletedItems: [CleanupItem],
        failedItems: [FailedItem],
        freedSpace: Int64,
        cleanupDate: Date = Date()
    ) {
        self.deletedItems = deletedItems
        self.failedItems = failedItems
        self.freedSpace = freedSpace
        self.cleanupDate = cleanupDate
    }
    
    public init(
        deletedItems: [CleanupItem],
        failedItems: [(CleanupItem, String)],
        freedSpace: Int64,
        cleanupDate: Date = Date()
    ) {
        self.deletedItems = deletedItems
        self.failedItems = failedItems.map { FailedItem(item: $0.0, error: $0.1) }
        self.freedSpace = freedSpace
        self.cleanupDate = cleanupDate
    }
}

public struct AppInfo: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let path: URL
    public let version: String?
    public let size: Int64?
    
    public init(
        name: String,
        bundleIdentifier: String,
        path: URL,
        version: String? = nil,
        size: Int64? = nil
    ) {
        self.id = bundleIdentifier
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.version = version
        self.size = size
    }
}

public struct LargeFile: Identifiable, Codable, Hashable {
    public let id: UUID
    public let path: URL
    public let size: Int64
    public let modifiedDate: Date?
    public let fileType: String
    
    public init(path: URL, size: Int64, modifiedDate: Date?, fileType: String) {
        self.id = UUID()
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
        self.fileType = fileType
    }
}

public struct DiskStatus: Codable {
    public let totalSpace: Int64
    public let usedSpace: Int64
    public let availableSpace: Int64
    public let volumeName: String
    
    public var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
    
    public init(totalSpace: Int64, usedSpace: Int64, availableSpace: Int64, volumeName: String) {
        self.totalSpace = totalSpace
        self.usedSpace = usedSpace
        self.availableSpace = availableSpace
        self.volumeName = volumeName
    }
}

public struct DuplicateFile: Identifiable, Codable, Hashable {
    public let id: UUID
    public let path: URL
    public let size: Int64
    public let hash: String
    public let modifiedDate: Date?
    public let fileType: String
    
    public init(path: URL, size: Int64, hash: String, modifiedDate: Date?, fileType: String) {
        self.id = UUID()
        self.path = path
        self.size = size
        self.hash = hash
        self.modifiedDate = modifiedDate
        self.fileType = fileType
    }
}

public struct DuplicateGroup: Identifiable, Codable, Hashable {
    public let id: UUID
    public let files: [DuplicateFile]
    public let fileSize: Int64
    public let hash: String
    
    public init(files: [DuplicateFile], hash: String) {
        self.id = UUID()
        self.files = files
        self.fileSize = files.first?.size ?? 0
        self.hash = hash
    }
    
    public var wastage: Int64 {
        guard files.count > 1 else { return 0 }
        return fileSize * Int64(files.count - 1)
    }
    
    public var totalSize: Int64 {
        fileSize * Int64(files.count)
    }
}

public struct DuplicatesScanResult: Codable {
    public let groups: [DuplicateGroup]
    public let totalFiles: Int
    public let totalWastage: Int64
    public let scanDate: Date
    public let scannedPaths: [String]
    
    public init(groups: [DuplicateGroup], scannedPaths: [String], scanDate: Date = Date()) {
        self.groups = groups
        self.scannedPaths = scannedPaths
        self.scanDate = scanDate
        self.totalFiles = groups.reduce(0) { $0 + $1.files.count }
        self.totalWastage = groups.reduce(0) { $0 + $1.wastage }
    }
}
