import Foundation
import Combine
import FitMacCore

@MainActor
class ScanManager: ObservableObject {
    static let shared = ScanManager()
    
    @Published var isScanningAll = false
    @Published var scanProgress: ScanProgress = .idle
    @Published var scanResults: [ScanType: Int64] = [:]
    
    private var scanTasks: [ScanType: Task<Void, Never>] = [:]
    
    enum ScanType: String, CaseIterable {
        case trash = "Trash"
        case cache = "Cache"
        case systemJunk = "System Junk"
        case languageFiles = "Language Files"
        case iTunes = "iTunes"
        case homebrew = "Homebrew"
        case loginItems = "Login Items"
        case systemApps = "System Apps"
    }
    
    enum ScanProgress: Equatable {
        case idle
        case scanning(current: ScanType, completed: Int, total: Int)
        case completed
        case error(String)
    }
    
    private init() {}
    
    func scanAll() {
        guard !isScanningAll else { return }
        
        isScanningAll = true
        scanResults = [:]
        
        let allTypes = ScanType.allCases
        var completedCount = 0
        
        for scanType in allTypes {
            scanProgress = .scanning(current: scanType, completed: completedCount, total: allTypes.count)
            
            let task = Task { [weak self] in
                if let size = await self?.performScan(scanType) {
                    await MainActor.run {
                        self?.scanResults[scanType] = size
                    }
                }
                completedCount += 1
            }
            scanTasks[scanType] = task
        }
        
        Task { [weak self] in
            for (_, task) in self?.scanTasks ?? [:] {
                await task.value
            }
            await MainActor.run {
                self?.isScanningAll = false
                self?.scanProgress = .completed
            }
        }
    }
    
    func cancelAll() {
        for (_, task) in scanTasks {
            task.cancel()
        }
        scanTasks = [:]
        isScanningAll = false
        scanProgress = .idle
    }
    
    private func performScan(_ type: ScanType) async -> Int64? {
        switch type {
        case .trash:
            let scanner = TrashScanner()
            let result = try? await scanner.scan()
            return result?.totalSize
        case .cache:
            let scanner = CacheScanner()
            let result = try? await scanner.scan()
            return result?.totalSize
        case .systemJunk:
            let scanner = SystemJunkScanner()
            let result = try? await scanner.scan()
            return result?.totalSize
        case .languageFiles:
            let scanner = LanguageScanner()
            let result = try? await scanner.scan()
            return result?.removableSize
        case .iTunes:
            let scanner = iTunesScanner()
            let result = try? await scanner.scan()
            return result?.totalSize
        case .homebrew:
            let scanner = HomebrewScanner()
            let result = await scanner.scan()
            return result.totalSize
        case .loginItems:
            let scanner = LoginItemsScanner()
            let result = await scanner.scan()
            return Int64(result.items.count)
        case .systemApps:
            let scanner = SystemAppScanner()
            let result = await scanner.scan()
            return result.totalSize
        }
    }
    
    var totalScannableSize: Int64 {
        scanResults.values.reduce(0, +)
    }
}
