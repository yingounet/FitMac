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
    @Published var sortOption: SortOption = .sizeDescending
    
    private let scanner = LanguageScanner()
    private let cleaner = LanguageCleaner()
    private var scanTask: Task<Void, Never>?
    
    enum SortOption: String, CaseIterable {
        case sizeDescending = "Size (Large to Small)"
        case sizeAscending = "Size (Small to Large)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
    }
    
    struct AppGroup: Identifiable, Hashable {
        let id: String
        let appName: String
        let items: [LanguageFile]
        let totalSize: Int64
        let selectedCount: Int
        let selectedSize: Int64
        
        var allSelected: Bool {
            selectedCount == items.count
        }
    }
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.items
            .filter { selectedItems.contains($0.id) && !$0.isCurrentLanguage }
            .reduce(0) { $0 + $1.size }
    }
    
    var removableItems: [LanguageFile] {
        scanResult?.removableItems ?? []
    }
    
    var appGroups: [AppGroup] {
        guard let result = scanResult else { return [] }
        let items = result.removableItems
        
        let grouped = Dictionary(grouping: items, by: { $0.appName })
        
        let groups = grouped.map { appName, items in
            let selectedItemsForApp = items.filter { selectedItems.contains($0.id) }
            return AppGroup(
                id: appName,
                appName: appName,
                items: items,
                totalSize: items.reduce(0) { $0 + $1.size },
                selectedCount: selectedItemsForApp.count,
                selectedSize: selectedItemsForApp.reduce(0) { $0 + $1.size }
            )
        }
        
        return sortGroups(groups)
    }
    
    private func sortGroups(_ groups: [AppGroup]) -> [AppGroup] {
        switch sortOption {
        case .sizeDescending:
            return groups.sorted { $0.totalSize > $1.totalSize }
        case .sizeAscending:
            return groups.sorted { $0.totalSize < $1.totalSize }
        case .nameAscending:
            return groups.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        case .nameDescending:
            return groups.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedDescending }
        }
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
    
    func selectApp(_ appName: String) {
        guard let result = scanResult else { return }
        let appItems = result.removableItems.filter { $0.appName == appName }
        for item in appItems {
            selectedItems.insert(item.id)
        }
    }
    
    func deselectApp(_ appName: String) {
        guard let result = scanResult else { return }
        let appItems = result.removableItems.filter { $0.appName == appName }
        for item in appItems {
            selectedItems.remove(item.id)
        }
    }
    
    func toggleApp(_ appName: String, selected: Bool) {
        if selected {
            selectApp(appName)
        } else {
            deselectApp(appName)
        }
    }
}
