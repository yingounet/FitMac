import Foundation
import FitMacCore
import Combine

@MainActor
final class SystemJunkViewModel: ObservableObject {
    @Published var scanResult: SystemJunkScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedCategories: Set<SystemJunkCategory> = Set(SystemJunkCategory.allCases)
    @Published var selectedItems: Set<UUID> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    
    private let scanner = SystemJunkScanner()
    private let cleaner = SystemJunkCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scan() {
        cancelScan()
        scanTask = Task { [weak self] in
            await self?.performScan()
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    private func performScan() async {
        isScanning = true
        errorMessage = nil
        cleanupResult = nil
        
        do {
            scanResult = try await scanner.scan()
            selectedItems = Set(scanResult?.items.filter { selectedCategories.contains($0.category) }.map(\.id) ?? [])
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func clean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.items.filter { selectedItems.contains($0.id) }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        do {
            cleanupResult = try await cleaner.clean(items: itemsToClean, dryRun: dryRun)
            
            if !dryRun, let cleanupResult = cleanupResult {
                let log = CleanupLog(
                    operation: "System Junk Cleanup",
                    itemsDeleted: cleanupResult.deletedItems.count,
                    freedSpace: cleanupResult.freedSpace,
                    details: cleanupResult.deletedItems.map { $0.path.path }
                )
                try? await CleanupLogger.shared.log(log)
                
                await performScan()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCleaning = false
    }
    
    func selectAll() {
        guard let result = scanResult else { return }
        selectedItems = Set(result.items.filter { selectedCategories.contains($0.category) }.map(\.id))
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
