import Foundation
import Combine
import FitMacCore

@MainActor
class BaseScanViewModel<T>: ObservableObject {
    @Published var isScanning = false
    @Published var isCancelled = false
    @Published var errorMessage: String?
    @Published var scanResult: T?
    @Published var scannedCount: Int = 0
    
    var scanTask: Task<Void, Never>?
    
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
    
    func performScan() async {
        fatalError("Subclasses must implement performScan()")
    }
    
    func handleError(_ error: Error) {
        if !Task.isCancelled && !error.isCancellation {
            if let fitMacError = error as? FitMacError {
                errorMessage = fitMacError.errorDescription
            } else if let scanError = error as? ScanError {
                errorMessage = scanError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}

@MainActor
class BaseCleanableViewModel<T>: BaseScanViewModel<T> {
    @Published var isCleaning = false
    @Published var cleanupResult: CleanupResult?
    
    var cleaningTask: Task<Void, Never>?
    
    func cancelCleaning() {
        cleaningTask?.cancel()
        cleaningTask = nil
        isCleaning = false
    }
    
    func performClean(dryRun: Bool) async {
        fatalError("Subclasses must implement performClean(dryRun:)")
    }
    
    func handleCleanupError(_ error: Error) {
        if !Task.isCancelled && !error.isCancellation {
            if let cleanError = error as? CleanError {
                errorMessage = cleanError.errorDescription
            } else {
                handleError(error)
            }
        }
    }
    
    func logCleanup(operation: String, result: CleanupResult) async {
        let log = CleanupLog(
            operation: operation,
            itemsDeleted: result.deletedItems.count,
            freedSpace: result.freedSpace,
            details: result.deletedItems.map { $0.path.path }
        )
        try? await CleanupLogger.shared.log(log)
    }
}
