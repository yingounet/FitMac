import Foundation
import FitMacCore
import Combine

@MainActor
final class HomebrewViewModel: ObservableObject {
    @Published var scanResult: HomebrewScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedItems: Set<UUID> = []
    @Published var cleanResult: HomebrewCleanResult?
    @Published var errorMessage: String?
    @Published var brewCleanupOutput: String?
    
    private let scanner = HomebrewScanner()
    private let cleaner = HomebrewCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    func scan() {
        cancelScan()
        brewCleanupOutput = nil
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
        cleanResult = nil
        
        let result = await scanner.scan()
        scanResult = result
        selectedItems = Set(result.items.map(\.id))
        
        isScanning = false
    }
    
    func cleanSelected(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.items.filter { selectedItems.contains($0.id) }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        let cleanResult = await cleaner.clean(items: itemsToClean, dryRun: dryRun)
        self.cleanResult = cleanResult
        
        if !dryRun {
            let log = CleanupLog(
                operation: "Homebrew Cache Cleanup",
                itemsDeleted: cleanResult.cleanedItems.count,
                freedSpace: cleanResult.freedSpace,
                details: cleanResult.cleanedItems.map { "\($0.name): \($0.path.path)" }
            )
            try? await CleanupLogger.shared.log(log)
            
            await performScan()
        }
        
        isCleaning = false
    }
    
    func runBrewCleanup() async {
        isCleaning = true
        errorMessage = nil
        brewCleanupOutput = nil
        
        let result = await cleaner.runBrewCleanup()
        
        if result.success {
            brewCleanupOutput = result.output.isEmpty ? "Cleanup completed successfully." : result.output
            
            let log = CleanupLog(
                operation: "Brew Cleanup",
                itemsDeleted: 0,
                freedSpace: 0,
                details: ["Ran: brew cleanup --prune=all", result.output]
            )
            try? await CleanupLogger.shared.log(log)
            
            await performScan()
        } else {
            errorMessage = "brew cleanup failed: \(result.output)"
        }
        
        isCleaning = false
    }
    
    func selectAll() {
        selectedItems = Set(scanResult?.items.map(\.id) ?? [])
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
