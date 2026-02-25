import ArgumentParser
import Foundation
import FitMacCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show disk usage and system status"
    )
    
    mutating func run() throws {
        guard let diskStatus = DiskUtils.getDiskStatus() else {
            throw RuntimeError("Unable to get disk status")
        }
        
        print("╔══════════════════════════════════════════════════════════╗")
        print("║                    FitMac Status                         ║")
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Volume: \(pad(diskStatus.volumeName, to: 44))║")
        print("║                                                          ║")
        print("║ Total:      \(pad(SizeFormatter.format(diskStatus.totalSpace), to: 42))║")
        print("║ Used:       \(pad(SizeFormatter.format(diskStatus.usedSpace), to: 42))║")
        print("║ Available:  \(pad(SizeFormatter.format(diskStatus.availableSpace), to: 42))║")
        print("║                                                          ║")
        
        let percentage = String(format: "%.1f%%", diskStatus.usedPercentage)
        let barWidth = 40
        let filledWidth = Int(Double(barWidth) * diskStatus.usedPercentage / 100)
        let emptyWidth = barWidth - filledWidth
        let bar = String(repeating: "█", count: filledWidth) + String(repeating: "░", count: emptyWidth)
        print("║ Usage: [\(bar)] \(pad(percentage, to: 6))║")
        print("╚══════════════════════════════════════════════════════════╝")
    }
}
