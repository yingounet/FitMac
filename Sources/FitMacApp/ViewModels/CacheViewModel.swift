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
    
    private let scanner = CacheScanner()
    private let cleaner = CacheCleaner()
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scan() async {
        isScanning = true
        errorMessage = nil
        cleanupResult = nil
        
        do {
            let categories = Array(selectedCategories)
            scanResult = try await scanner.scan(categories: categories)
            selectedItems = Set(scanResult?.items.map(\.path) ?? [])
        } catch {
            errorMessage = error.localizedDescription
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
