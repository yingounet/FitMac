import Foundation
import CryptoKit

public actor DuplicateScanner {
    public init() {}
    
    public func scan(
        paths: [URL],
        minSize: Int64 = 1024,
        maxFiles: Int = 10000,
        progress: @escaping (Int) -> Void = { _ in }
    ) async throws -> DuplicatesScanResult {
        var hashToFiles: [String: [DuplicateFile]] = [:]
        var scannedCount = 0
        let fileManager = FileManager.default
        
        for searchPath in paths {
            guard let enumerator = fileManager.enumerator(
                at: searchPath,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                if scannedCount >= maxFiles { break }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [
                        .fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .contentTypeKey
                    ])
                    
                    guard resourceValues.isDirectory != true,
                          let fileSize = resourceValues.fileSize,
                          Int64(fileSize) >= minSize else { continue }
                    
                    let hash = try computeFileHash(at: fileURL)
                    let fileType = fileURL.pathExtension.lowercased()
                    
                    let dupFile = DuplicateFile(
                        path: fileURL,
                        size: Int64(fileSize),
                        hash: hash,
                        modifiedDate: resourceValues.contentModificationDate,
                        fileType: fileType
                    )
                    
                    hashToFiles[hash, default: []].append(dupFile)
                    scannedCount += 1
                    progress(scannedCount)
                } catch {
                    continue
                }
            }
        }
        
        let duplicateGroups = hashToFiles
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(files: $0.value, hash: $0.key) }
            .sorted { $0.wastage > $1.wastage }
        
        return DuplicatesScanResult(
            groups: duplicateGroups,
            scannedPaths: paths.map { $0.path }
        )
    }
    
    private func computeFileHash(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}

public actor DuplicateCleaner {
    public init() {}
    
    public func clean(
        files: [DuplicateFile],
        dryRun: Bool = true
    ) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for file in files {
            let item = CleanupItem(
                path: file.path,
                category: .temporary,
                size: file.size,
                isDirectory: false,
                modifiedDate: file.modifiedDate
            )
            
            if dryRun {
                deletedItems.append(item)
                freedSpace += file.size
            } else {
                do {
                    _ = try FileUtils.moveToTrash(at: file.path)
                    deletedItems.append(item)
                    freedSpace += file.size
                } catch {
                    failedItems.append(FailedItem(item: item, error: error.localizedDescription))
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
