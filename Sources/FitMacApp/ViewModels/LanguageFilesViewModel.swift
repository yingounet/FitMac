import Foundation
import FitMacCore
import Combine

@MainActor
final class LanguageFilesViewModel: ObservableObject {
    @Published var scanResult: LanguageScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedItems: Set<UUID> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    @Published var scannedCount: Int = 0
    
    private let scanner = LanguageScanner()
    private let cleaner = LanguageCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.id) && !$0.isCurrentLanguage }
            .reduce(0) { $0 + $1.size }
    }
    
    var removableItems: [LanguageFile] {
        scanResult?.removableItems ?? []
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
        scannedCount = 0
        
        do {
            scanResult = try await scanner.scan()
            scannedCount = scanResult?.items.count ?? 0
            selectedItems = Set(scanResult?.removableItems.map(\.id) ?? [])
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func clean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.items.filter { selectedItems.contains($0.id) && !$0.isCurrentLanguage }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        do {
            cleanupResult = try await cleaner.clean(items: itemsToClean, dryRun: dryRun)
            
            if !dryRun, let cleanupResult = cleanupResult {
                let log = CleanupLog(
                    operation: "Language Files Cleanup",
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
        selectedItems = Set(scanResult?.removableItems.map(\.id) ?? [])
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
