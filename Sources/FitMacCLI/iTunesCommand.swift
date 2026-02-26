import ArgumentParser
import Foundation
import FitMacCore

struct iTunesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "itunes",
        abstract: "Scan and clean iTunes junk (iOS backups, podcasts, etc.)"
    )
    
    @Flag(name: .long, help: "List all iTunes junk items")
    var list = false
    
    @Flag(name: .long, help: "Scan and display iTunes junk")
    var scan = false
    
    @Flag(name: .long, help: "Clean iTunes junk files")
    var clean = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    @Option(name: .shortAndLong, help: "Filter by category: backup, podcast, apps, all")
    var category: String = "all"
    
    mutating func run() async throws {
        let scanner = iTunesScanner()
        
        print("Scanning iTunes junk...")
        let result = try await scanner.scan()
        
        if result.items.isEmpty {
            print("No iTunes junk found.")
            return
        }
        
        let filteredItems = filterItems(result.items)
        
        if filteredItems.isEmpty {
            print("No items found for selected category.")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              iTunes Junk Scan Results                    ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for category in iTunesJunkCategory.allCases {
            let items = filteredItems.filter { $0.category == category }
            if !items.isEmpty {
                let totalSize = items.reduce(0) { $0 + $1.size }
                print("║ 📱 \(category.displayName)")
                for item in items {
                    print("║     Name: \(pad(item.name, to: 48))║")
                    print("║     Size: \(pad(SizeFormatter.format(item.size), to: 48))║")
                    if let details = item.details {
                        print("║     Info: \(pad(details, to: 48))║")
                    }
                    let shortPath = PathUtils.shorten(item.path.path)
                    print("║     Path: \(pad(shortPath, to: 48))║")
                    print("╠══════════════════════════════════════════════════════════╣")
                }
            }
        }
        
        let totalSize = filteredItems.reduce(0) { $0 + $1.size }
        print("║ Total: \(pad(SizeFormatter.format(totalSize), to: 49))║")
        print("║ Items: \(pad("\(filteredItems.count)", to: 50))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if !force {
                print("\n⚠️  This will clean \(filteredItems.count) item(s)")
                print("   Space to free: \(SizeFormatter.format(totalSize))")
                print("   ⚠️  iOS backups cannot be restored after deletion!")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = iTunesJunkCleaner()
            let cleanResult = try await cleaner.clean(items: filteredItems, dryRun: false)
            
            print("\n✅ Cleaned \(cleanResult.deletedItems.count) items")
            print("   Freed: \(SizeFormatter.format(cleanResult.freedSpace))")
            
            if !cleanResult.failedItems.isEmpty {
                print("\n❌ Failed to clean \(cleanResult.failedItems.count) items:")
                for failed in cleanResult.failedItems {
                    print("   • \(failed.item.path.lastPathComponent): \(failed.error)")
                }
            }
        }
    }
    
    private func filterItems(_ items: [iTunesJunkItem]) -> [iTunesJunkItem] {
        switch category.lowercased() {
        case "backup":
            return items.filter { $0.category == .iOSBackup }
        case "podcast":
            return items.filter { $0.category == .podcastDownloads }
        case "apps":
            return items.filter { $0.category == .oldMobileApps }
        default:
            return items
        }
    }
    
    private func pad(_ string: String, to length: Int) -> String {
        let padded = string.padding(toLength: length, withPad: " ", startingAt: 0)
        return String(padded.prefix(length))
    }
}
