import ArgumentParser
import Foundation
import FitMacCore

struct TrashCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trash",
        abstract: "Scan and empty trash bins"
    )
    
    @Flag(name: .long, help: "List all trash bins with sizes")
    var list = false
    
    @Flag(name: .long, help: "Empty all trash bins")
    var empty = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    mutating func run() async throws {
        let scanner = TrashScanner()
        
        print("Scanning trash bins...")
        let result = try await scanner.scan()
        
        if result.bins.isEmpty {
            print("No trash bins found or all are empty.")
            return
        }
        
        if list || !empty {
            print("\n╔══════════════════════════════════════════════════════════╗")
            print("║                  Trash Bins Overview                     ║")
            print("╠══════════════════════════════════════════════════════════╣")
            
            for bin in result.bins {
                let icon = bin.isExternal ? "🔌" : "🗑️"
                let sizeStr = SizeFormatter.format(bin.size)
                print("║ \(icon) \(bin.name)")
                print("║     Path: \(pad(PathUtils.shorten(bin.path.path), to: 48))")
                print("║     Size: \(pad(sizeStr, to: 48))")
                print("║     Volume: \(pad(bin.volumeName, to: 46))")
                print("╠══════════════════════════════════════════════════════════╣")
            }
            
            print("║ Total: \(pad(SizeFormatter.format(result.totalSize), to: 49))║")
            print("║ Bins: \(pad("\(result.bins.count) trash bin(s)", to: 50))║")
            print("╚══════════════════════════════════════════════════════════╝")
        }
        
        if empty {
            if !force {
                print("\n⚠️  This will permanently empty \(result.bins.count) trash bin(s)")
                print("   Total size to free: \(SizeFormatter.format(result.totalSize))")
                print("   This action cannot be undone!")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = TrashCleaner()
            let emptyResult = await cleaner.emptyAll(bins: result.bins, dryRun: false)
            
            print("\n✅ Emptied \(emptyResult.emptiedBins.count) trash bin(s)")
            print("   Freed: \(SizeFormatter.format(emptyResult.freedSpace))")
            
            if !emptyResult.failedBins.isEmpty {
                print("\n❌ Failed to empty \(emptyResult.failedBins.count) bin(s):")
                for failed in emptyResult.failedBins {
                    print("   • \(failed.bin.name): \(failed.error)")
                }
            }
        }
    }
    
    private func pad(_ string: String, to length: Int) -> String {
        let padded = string.padding(toLength: length, withPad: " ", startingAt: 0)
        return String(padded.prefix(length))
    }
}
