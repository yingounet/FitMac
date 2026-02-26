import Foundation
import FitMacCore
import Combine

@MainActor
final class LogViewModel: ObservableObject {
    @Published var logs: [CleanupLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            logs = try await CleanupLogger.shared.loadLogs()
                .sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearLogs() async {
        do {
            try await CleanupLogger.shared.clearLogs()
            logs = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
