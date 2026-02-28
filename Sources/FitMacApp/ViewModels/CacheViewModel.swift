import Foundation
import FitMacCore
import Combine

@MainActor
final class CacheViewModel: BaseCleanableViewModel<ScanResult> {
    @Published var selectedCategories: Set<CacheCategory> = Set(CacheCategory.allCases)
    @Published var selectedItems: Set<URL> = []
    
    private let scanner = CacheScanner()
    private let cleaner = CacheCleaner()
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }
    
    override func performScan() async {
        isScanning = true
        clearError()
        cleanupResult = nil
        scannedCount = 0
        
        do {
            let categories = Array(selectedCategories)
            let result = try await scanner.scan(categories: categories)
            scanResult = result
            selectedItems = Set(result.items.map(\.path))
            scannedCount = result.items.count
        } catch {
            handleError(error)
        }
        
        isScanning = false
    }
    
    override func performClean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.items.filter { selectedItems.contains($0.path) }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        clearError()
        
        do {
            let result = try await cleaner.clean(items: itemsToClean, dryRun: dryRun)
            cleanupResult = result
            
            if !dryRun {
                await logCleanup(operation: "Cache Cleanup", result: result)
            }
        } catch {
            handleCleanupError(error)
        }
        
        isCleaning = false
    }
    
    func clean(dryRun: Bool) async {
        await performClean(dryRun: dryRun)
    }
    
    func selectAll() {
        selectedItems = Set(scanResult?.items.map(\.path) ?? [])
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
