import Foundation
import FitMacCore
import Combine

@MainActor
final class SystemAppViewModel: ObservableObject {
    @Published var scanResult: SystemAppScanResult?
    @Published var isScanning = false
    @Published var isRemoving = false
    @Published var selectedApps: Set<String> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    @Published var showRemoveConfirmation = false
    @Published var appToRemove: SystemApp?
    
    private let scanner = SystemAppScanner()
    private var scanTask: Task<Void, Never>?
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.apps
            .filter { selectedApps.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    var hasWarningSelected: Bool {
        guard let result = scanResult else { return false }
        return result.apps
            .filter { selectedApps.contains($0.id) }
            .contains { $0.warningLevel == .warning }
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
        
        scanResult = await scanner.scan()
        
        isScanning = false
    }
    
    func confirmRemove(_ app: SystemApp) {
        appToRemove = app
        showRemoveConfirmation = true
    }
    
    func removeApp(_ app: SystemApp, dryRun: Bool) async {
        isRemoving = true
        errorMessage = nil
        
        do {
            cleanupResult = try await scanner.removeApp(app, dryRun: dryRun)
            
            if !dryRun {
                let log = CleanupLog(
                    operation: "System App Removal",
                    itemsDeleted: cleanupResult?.deletedItems.count ?? 0,
                    freedSpace: cleanupResult?.freedSpace ?? 0,
                    details: ["Removed: \(app.name)"]
                )
                try? await CleanupLogger.shared.log(log)
                
                await performScan()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRemoving = false
        showRemoveConfirmation = false
        appToRemove = nil
    }
    
    func selectAll() {
        guard let result = scanResult else { return }
        selectedApps = Set(result.apps.map(\.id))
    }
    
    func deselectAll() {
        selectedApps = []
    }
}
