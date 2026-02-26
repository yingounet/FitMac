import Foundation
import FitMacCore
import Combine

@MainActor
final class MailAttachmentsViewModel: ObservableObject {
    @Published var scanResult: MailScanResult?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var selectedItems: Set<UUID> = []
    @Published var cleanupResult: CleanupResult?
    @Published var errorMessage: String?
    @Published var minSizeKB: Int64 = 100
    @Published var sortBy: SortOption = .size
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case date = "Date"
        case name = "Name"
        case mailbox = "Mailbox"
    }
    
    private let cleaner = MailCleaner()
    private var scanTask: Task<Void, Never>?
    
    var sortedAttachments: [MailAttachment] {
        guard let result = scanResult else { return [] }
        switch sortBy {
        case .size:
            return result.attachments.sorted { $0.size > $1.size }
        case .date:
            return result.attachments.sorted { ($0.receivedDate ?? .distantPast) > ($1.receivedDate ?? .distantPast) }
        case .name:
            return result.attachments.sorted { $0.filename < $1.filename }
        case .mailbox:
            return result.attachments.sorted { ($0.mailbox ?? "") < ($1.mailbox ?? "") }
        }
    }
    
    var totalSelectedSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.attachments
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
            let scanner = MailScanner(minSizeKB: minSizeKB)
            scanResult = try await scanner.scan()
            selectedItems = Set(scanResult?.attachments.map(\.id) ?? [])
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isScanning = false
    }
    
    func clean(dryRun: Bool) async {
        guard let result = scanResult else { return }
        
        let itemsToClean = result.attachments.filter { selectedItems.contains($0.id) }
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        errorMessage = nil
        
        do {
            cleanupResult = try await cleaner.clean(attachments: itemsToClean, dryRun: dryRun)
            
            if !dryRun, let cleanupResult = cleanupResult {
                let log = CleanupLog(
                    operation: "Mail Attachments Cleanup",
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
        selectedItems = Set(scanResult?.attachments.map(\.id) ?? [])
    }
    
    func deselectAll() {
        selectedItems = []
    }
}
