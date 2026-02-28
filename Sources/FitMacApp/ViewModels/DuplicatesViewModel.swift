import Foundation
import FitMacCore
import Combine

@MainActor
final class DuplicatesViewModel: ObservableObject {
    @Published var scanResult: DuplicatesScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedFiles: Set<URL> = []
    @Published var expandedGroups: Set<UUID> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    @Published var scannedCount: Int = 0
    @Published var isCancelled = false
    @Published var minSize: String = "1"
    @Published var scanPath: URL = URL(fileURLWithPath: NSHomeDirectory())
    
    private let scanner = DuplicateScanner()
    private let cleaner = DuplicateCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.groups
            .flatMap { $0.files }
            .filter { selectedFiles.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }
    
    var minSizeBytes: Int64 {
        Int64(minSize) ?? 1 * 1024 * 1024
    }
    
    func scan() {
        cancelScan()
        isCancelled = false
        scanTask = Task { [weak self] in
            await self?.performScan()
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        isCancelled = true
    }
    
    private func performScan() async {
        isScanning = true
        errorMessage = nil
        cleanupResult = nil
        scannedCount = 0
        selectedFiles = []
        expandedGroups = []
        
        do {
            let paths = [scanPath]
            scanResult = try await scanner.scan(
                paths: paths,
                minSize: minSizeBytes,
                maxFiles: 5000
            ) { count in
                Task { @MainActor in
                    self.scannedCount = count
                }
            }
            
            if let result = scanResult {
                expandedGroups = Set(result.groups.prefix(5).map(\.id))
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func clean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let filesToClean = result.groups
            .flatMap { $0.files }
            .filter { selectedFiles.contains($0.path) }
        
        guard !filesToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        do {
            cleanupResult = try await cleaner.clean(files: filesToClean, dryRun: dryRun)
            
            if !dryRun, let cleanupResult = cleanupResult {
                let log = CleanupLog(
                    operation: "Duplicates Cleanup",
                    itemsDeleted: cleanupResult.deletedItems.count,
                    freedSpace: cleanupResult.freedSpace,
                    details: cleanupResult.deletedItems.map { $0.path.path }
                )
                try? await CleanupLogger.shared.log(log)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCleaning = false
    }
    
    func selectDuplicatesInGroup(_ group: DuplicateGroup, keepFirst: Bool = true) {
        let filesToSelect = keepFirst ? group.files.dropFirst() : group.files.dropLast()
        for file in filesToSelect {
            selectedFiles.insert(file.path)
        }
    }
    
    func deselectAllInGroup(_ group: DuplicateGroup) {
        for file in group.files {
            selectedFiles.remove(file.path)
        }
    }
    
    func selectAllDuplicates() {
        guard let result = scanResult else { return }
        for group in result.groups where group.files.count > 1 {
            for file in group.files.dropFirst() {
                selectedFiles.insert(file.path)
            }
        }
    }
    
    func deselectAll() {
        selectedFiles = []
    }
}
