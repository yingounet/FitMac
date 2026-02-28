import Foundation
import FitMacCore
import Combine

@MainActor
final class LargeFilesViewModel: BaseScanViewModel<[LargeFile]> {
    @Published var selectedFiles: Set<URL> = []
    @Published var minSize: String = "100 MB"
    @Published var scanPath: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var sortBy: SortOption = .size
    @Published var maxResults = 50
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case date = "Date Modified"
    }
    
    var minSizeBytes: Int64 {
        PathUtils.parseSize(minSize)
    }
    
    var totalSelectedSize: Int64 {
        files.filter { selectedFiles.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }
    
    var files: [LargeFile] {
        scanResult ?? []
    }
    
    override func performScan() async {
        isScanning = true
        clearError()
        selectedFiles = []
        scannedCount = 0
        
        var foundFiles: [LargeFile] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: scanPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .typeIdentifierKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            handleError(ScanError.directoryNotReadable(path: scanPath.path))
            isScanning = false
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                isScanning = false
                return
            }
            
            scannedCount += 1
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey, .typeIdentifierKey, .isDirectoryKey
                ])
                
                guard resourceValues.isDirectory != true else { continue }
                
                let size = Int64(resourceValues.fileSize ?? 0)
                guard size >= minSizeBytes else { continue }
                
                let modifiedDate = resourceValues.contentModificationDate
                let fileType = resourceValues.typeIdentifier ?? "public.data"
                
                foundFiles.append(LargeFile(
                    path: fileURL,
                    size: size,
                    modifiedDate: modifiedDate,
                    fileType: fileType
                ))
            } catch {
                continue
            }
        }
        
        if sortBy == .size {
            foundFiles.sort { $0.size > $1.size }
        } else {
            foundFiles.sort { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
        }
        
        scanResult = Array(foundFiles.prefix(maxResults))
        isScanning = false
    }
    
    func deleteSelected() async -> Bool {
        var success = true
        let deletedFiles = files.filter { selectedFiles.contains($0.path) }
        let totalFreed = totalSelectedSize
        
        for path in selectedFiles {
            do {
                _ = try FileUtils.moveToTrash(at: path)
                scanResult?.removeAll { $0.path == path }
            } catch {
                handleError(CleanError.moveToTrashFailed(path: path.path, underlying: error))
                success = false
            }
        }
        
        if success && !deletedFiles.isEmpty {
            let log = CleanupLog(
                operation: "Large Files Cleanup",
                itemsDeleted: deletedFiles.count,
                freedSpace: totalFreed,
                details: deletedFiles.map { $0.path.path }
            )
            try? await CleanupLogger.shared.log(log)
        }
        
        selectedFiles = []
        return success
    }
    
    func selectAll() {
        selectedFiles = Set(files.map(\.path))
    }
    
    func deselectAll() {
        selectedFiles = []
    }
}
