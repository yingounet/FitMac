import Foundation
import FitMacCore
import Combine

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var scanResult: TrashScanResult?
    @Published var isScanning = false
    @Published var isEmptying = false
    @Published var selectedBins: Set<UUID> = []
    @Published var emptyResult: TrashEmptyResult?
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    
    private let scanner = TrashScanner()
    private let cleaner = TrashCleaner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.bins
            .filter { selectedBins.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    var hasExternalBins: Bool {
        scanResult?.bins.contains { $0.isExternal } ?? false
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
        emptyResult = nil
        
        do {
            scanResult = try await scanner.scan()
            selectedBins = Set(scanResult?.bins.map(\.id) ?? [])
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func emptySelected(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let binsToEmpty = result.bins.filter { selectedBins.contains($0.id) }
        guard !binsToEmpty.isEmpty else { return }
        
        isEmptying = true
        errorMessage = nil
        
        let emptyResult = await cleaner.emptyAll(bins: binsToEmpty, dryRun: dryRun)
        self.emptyResult = emptyResult
        
        if !dryRun {
            let log = CleanupLog(
                operation: "Empty Trash",
                itemsDeleted: emptyResult.emptiedBins.count,
                freedSpace: emptyResult.freedSpace,
                details: emptyResult.emptiedBins.map { "\($0.name): \($0.path.path)" }
            )
            try? await CleanupLogger.shared.log(log)
            
            await performScan()
        }
        
        isEmptying = false
    }
    
    func selectAll() {
        selectedBins = Set(scanResult?.bins.map(\.id) ?? [])
    }
    
    func deselectAll() {
        selectedBins = []
    }
}
