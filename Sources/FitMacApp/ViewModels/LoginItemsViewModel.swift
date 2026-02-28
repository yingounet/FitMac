import Foundation
import FitMacCore
import Combine

@MainActor
final class LoginItemsViewModel: ObservableObject {
    @Published var scanResult: LoginItemsScanResult?
    @Published var isScanning = false
    @Published var isToggling = false
    @Published var togglingItemId: UUID?
    @Published var errorMessage: String?
    
    private let scanner = LoginItemsScanner()
    private let manager = LoginItemsManager()
    private var scanTask: Task<Void, Never>?
    
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
        
        let result = await scanner.scan()
        scanResult = result
        
        isScanning = false
    }
    
    func toggle(item: LoginItem, enable: Bool) async {
        togglingItemId = item.id
        isToggling = true
        errorMessage = nil
        
        let result = await manager.toggle(item: item, enable: enable)
        
        if result.success {
            await performScan()
        } else {
            errorMessage = "Failed to \(enable ? "enable" : "disable") '\(item.name)': \(result.error ?? "Unknown error")"
        }
        
        togglingItemId = nil
        isToggling = false
    }
    
    func remove(item: LoginItem) async {
        errorMessage = nil
        
        let result = await manager.remove(item: item)
        
        if result.success {
            let log = CleanupLog(
                operation: "Remove Login Item",
                itemsDeleted: 1,
                freedSpace: 0,
                details: ["Removed: \(item.name)", "Path: \(item.path.path)"]
            )
            try? await CleanupLogger.shared.log(log)
            
            await performScan()
        } else {
            errorMessage = "Failed to remove '\(item.name)': \(result.error ?? "Unknown error")"
        }
    }
}
