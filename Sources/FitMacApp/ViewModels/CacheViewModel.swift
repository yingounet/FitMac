import Foundation
import FitMacCore
import Combine

@MainActor
final class CacheViewModel: ObservableObject {
    @Published var scanResult: ScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedCategories: Set<CacheCategory> = Set(CacheCategory.allCases)
    @Published var selectedItems: Set<URL> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    @Published var scannedCount: Int = 0
    @Published var isCancelled = false
    
    private let scanner = CacheScanner()
    private let cleaner = CacheCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.path) }
            .reduce(0) { $0 + $1.size }
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
        
        do {
            let categories = Array(selectedCategories)
            scanResult = try await scanner.scan(categories: categories)
            selectedItems = Set(scanResult?.items.map(\.path) ?? [])
            scannedCount = scanResult?.items.count ?? 0
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func clean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.items.filter { selectedItems.contains($0.path) }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        do {
            cleanupResult = try await cleaner.clean(items: itemsToClean, dryRun: dryRun)
            
            if !dryRun, let cleanupResult = cleanupResult {
                let log = CleanupLog(
                    operation: "Cache Cleanup",
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
    
    func selectAll() {
        selectedItems = Set(scanResult?.items.map(\.path) ?? [])
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
