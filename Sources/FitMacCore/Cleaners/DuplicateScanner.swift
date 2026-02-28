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
        var sizeToFiles: [Int64: [DuplicateFile]] = [:]
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
                    
                    let fileType = fileURL.pathExtension.lowercased()
                    let size = Int64(fileSize)
                    
                    let dupFile = DuplicateFile(
                        path: fileURL,
                        size: size,
                        hash: "",
                        modifiedDate: resourceValues.contentModificationDate,
                        fileType: fileType
                    )
                    
                    sizeToFiles[size, default: []].append(dupFile)
                    scannedCount += 1
                    progress(scannedCount)
                } catch {
                    continue
                }
            }
        }
        
        var hashToFiles: [String: [DuplicateFile]] = [:]
        
        for (size, files) in sizeToFiles where files.count > 1 {
            for file in files {
                if Task.isCancelled { break }
                
                do {
                    let hash = try computeFileHash(at: file.path, size: size)
                    let dupFile = DuplicateFile(
                        path: file.path,
                        size: file.size,
                        hash: hash,
                        modifiedDate: file.modifiedDate,
                        fileType: file.fileType
                    )
                    hashToFiles[hash, default: []].append(dupFile)
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
    
    private func computeFileHash(at url: URL, size: Int64) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        let chunkSize: Int64 = 1024 * 1024
        var hasher = Insecure.MD5()
        
        if size <= chunkSize * 3 {
            if let data = try fileHandle.readToEnd() {
                hasher.update(data: data)
            }
        } else {
            if let headData = try fileHandle.read(upToCount: Int(chunkSize)) {
                hasher.update(data: headData)
            }
            
            try fileHandle.seek(toOffset: UInt64(size / 2))
            if let middleData = try fileHandle.read(upToCount: Int(chunkSize)) {
                hasher.update(data: middleData)
            }
            
            try fileHandle.seek(toOffset: UInt64(size - chunkSize))
            if let tailData = try fileHandle.read(upToCount: Int(chunkSize)) {
                hasher.update(data: tailData)
            }
            
            var sizeData = Data()
            sizeData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
            hasher.update(data: sizeData)
        }
        
        let hash = hasher.finalize()
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
