import Foundation

public enum SizeFormatter {
    public static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    public static func format(_ bytes: UInt64) -> String {
        format(Int64(bytes))
    }
}

public enum FileUtils {
    public static func sizeOfItem(at url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        
        if resourceValues.isDirectory == true {
            return try sizeOfDirectory(at: url)
        } else {
            return Int64(resourceValues.fileSize ?? 0)
        }
    }
    
    public static func sizeOfDirectory(at url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .totalFileSizeKey])
                if resourceValues.isDirectory != true {
                    totalSize += Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    public static func moveToTrash(at url: URL) throws -> URL? {
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        return resultURL as URL?
    }
    
    public static func modifiedDate(at url: URL) throws -> Date? {
        let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
        return resourceValues.contentModificationDate
    }
    
    public static func isDirectory(at url: URL) throws -> Bool {
        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
        return resourceValues.isDirectory ?? false
    }
}

public enum DiskUtils {
    public static func getDiskStatus(for path: URL = URL(fileURLWithPath: "/")) -> DiskStatus? {
        do {
            let values = try path.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey
            ])
            
            let totalSpace = Int64(values.volumeTotalCapacity ?? 0)
            let availableSpace = Int64(values.volumeAvailableCapacity ?? 0)
            let usedSpace = totalSpace - availableSpace
            let volumeName = values.volumeName ?? "Macintosh HD"
            
            return DiskStatus(
                totalSpace: totalSpace,
                usedSpace: usedSpace,
                availableSpace: availableSpace,
                volumeName: volumeName
            )
        } catch {
            return nil
        }
    }
}

public let fitMacLogDirectory: URL = {
    let paths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
    return paths[0].appendingPathComponent("Logs").appendingPathComponent("FitMac")
}()

public func ensureLogDirectory() throws {
    try FileManager.default.createDirectory(at: fitMacLogDirectory, withIntermediateDirectories: true)
}
