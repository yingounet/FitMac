import Foundation
import FitMacCore
import Combine

@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var files: [LargeFile] = []
    @Published var isScanning = false
    @Published var selectedFiles: Set<URL> = []
    @Published var minSize: String = "100 MB"
    @Published var scanPath: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var sortBy: SortOption = .size
    @Published var maxResults = 50
    @Published var errorMessage: String?
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case date = "Date Modified"
    }
    
    var minSizeBytes: Int64 {
        parseSize(minSize)
    }
    
    var totalSelectedSize: Int64 {
        files.filter { selectedFiles.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scan() async {
        isScanning = true
        errorMessage = nil
        selectedFiles = []
        
        var foundFiles: [LargeFile] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: scanPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .typeIdentifierKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            errorMessage = "Unable to scan directory"
            isScanning = false
            return
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
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
        
        files = Array(foundFiles.prefix(maxResults))
        isScanning = false
    }
    
    func deleteSelected() async -> Bool {
        var success = true
        for path in selectedFiles {
            do {
                _ = try FileUtils.moveToTrash(at: path)
                files.removeAll { $0.path == path }
            } catch {
                errorMessage = "Failed to delete \(path.lastPathComponent): \(error.localizedDescription)"
                success = false
            }
        }
        selectedFiles = []
        return success
    }
    
    private func parseSize(_ string: String) -> Int64 {
        let str = string.uppercased().replacingOccurrences(of: " ", with: "")
        
        if str.hasSuffix("GB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1_073_741_824)
        } else if str.hasSuffix("MB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1_048_576)
        } else if str.hasSuffix("KB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1024)
        } else {
            return Int64(str) ?? 0
        }
    }
}
