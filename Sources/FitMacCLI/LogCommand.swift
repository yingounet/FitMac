import ArgumentParser
import Foundation
import FitMacCore

struct LogCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "log",
        abstract: "View cleanup history"
    )
    
    @Flag(name: .shortAndLong, help: "List all cleanup logs")
    var list = false
    
    @Flag(name: .shortAndLong, help: "Clear all cleanup logs")
    var clear = false
    
    @Option(name: .shortAndLong, help: "Show last N entries (default: 10)")
    var last: Int = 10
    
    mutating func run() async throws {
        if clear {
            try await clearLogs()
            return
        }
        
        try await listLogs()
    }
    
    private func listLogs() async throws {
        let logs = try await CleanupLogger.shared.loadLogs()
            .sorted { $0.date > $1.date }
        
        if logs.isEmpty {
            print("No cleanup history found.")
            return
        }
        
        let displayLogs = Array(logs.prefix(last))
        
        print("╔══════════════════════════════════════════════════════════╗")
        print("║                  Cleanup History                         ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for (index, log) in displayLogs.enumerated() {
            let dateStr = log.date.formatted(date: .abbreviated, time: .shortened)
            let opStr = pad(log.operation, to: 25)
            let itemsStr = "\(log.itemsDeleted) items"
            let sizeStr = SizeFormatter.format(log.freedSpace)
            
            print("║ \(String(format: "%2d", index + 1)). \(opStr)║")
            print("║     Date: \(pad(dateStr, to: 44))║")
            print("║     \(pad(itemsStr, to: 10)) • \(pad(sizeStr, to: 37))║")
            
            if index < displayLogs.count - 1 {
                print("╟──────────────────────────────────────────────────────────╢")
            }
        }
        
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Showing \(displayLogs.count) of \(logs.count) entries\(pad("", to: 36))║")
        print("╚══════════════════════════════════════════════════════════╝")
    }
    
    private func clearLogs() async throws {
        print("⚠️  This will delete all cleanup history.")
        print("Continue? [y/N]: ", terminator: "")
        
        guard readLine()?.lowercased() == "y" else {
            print("Cancelled.")
            return
        }
        
        try await CleanupLogger.shared.clearLogs()
        print("✅ Cleanup history cleared.")
    }
}
