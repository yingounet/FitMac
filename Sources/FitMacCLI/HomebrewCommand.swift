import ArgumentParser
import Foundation
import FitMacCore

struct HomebrewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "homebrew",
        abstract: "Scan and clean Homebrew cache and old versions"
    )
    
    @Flag(name: .long, help: "Scan and display Homebrew cache files")
    var scan = false
    
    @Flag(name: .long, help: "Clean Homebrew cache files")
    var clean = false
    
    @Flag(name: .long, help: "Run 'brew cleanup' command")
    var brewCleanup = false
    
    @Flag(name: .long, help: "Actually delete files (default is dry-run)")
    var noDryRun = false
    
    @Option(name: .shortAndLong, help: "Filter by type: cache, downloads, logs, old, all")
    var type: String = "all"
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    private var dryRun: Bool { !noDryRun }
    
    mutating func run() async throws {
        let scanner = HomebrewScanner()
        
        if brewCleanup {
            try await runBrewCleanupCommand()
            return
        }
        
        print("Scanning Homebrew cache...")
        let result = await scanner.scan()
        
        if !result.isHomebrewInstalled {
            print("❌ Homebrew is not installed.")
            print("   Install it from: https://brew.sh")
            return
        }
        
        if let brewPath = result.brewPath {
            print("   Homebrew found at: \(brewPath)")
        }
        
        let filteredItems = filterItems(result.items)
        
        if filteredItems.isEmpty {
            print("\n✅ No Homebrew cache files found.")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              Homebrew Cache Scan Results                 ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for itemType in HomebrewItemType.allCases {
            let items = filteredItems.filter { $0.type == itemType }
            if !items.isEmpty {
                let totalSize = items.reduce(0) { $0 + $1.size }
                print("║ \(itemType.displayName): \(pad(SizeFormatter.format(totalSize), to: 45))║")
                for item in items.prefix(5) {
                    let shortPath = shortenPath(item.path.path)
                    print("║   • \(pad(shortPath, to: 50))║")
                }
                if items.count > 5 {
                    print("║   ... and \(items.count - 5) more items                                 ║")
                }
            }
        }
        
        let totalSize = filteredItems.reduce(0) { $0 + $1.size }
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(pad(SizeFormatter.format(totalSize), to: 48))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if dryRun {
                print("\n[DRY-RUN] Would clean \(filteredItems.count) items, freeing \(SizeFormatter.format(totalSize))")
            } else {
                if !force {
                    print("\n⚠️  This will delete \(filteredItems.count) items (\(SizeFormatter.format(totalSize)))")
                    print("Continue? [y/N]: ", terminator: "")
                    guard readLine()?.lowercased() == "y" else {
                        print("Cancelled.")
                        return
                    }
                }
                
                let cleaner = HomebrewCleaner()
                let cleanResult = await cleaner.clean(items: filteredItems, dryRun: false)
                
                print("\n✅ Cleaned \(cleanResult.cleanedItems.count) items")
                print("   Freed: \(SizeFormatter.format(cleanResult.freedSpace))")
                
                if !cleanResult.failedItems.isEmpty {
                    print("\n❌ Failed to clean \(cleanResult.failedItems.count) items:")
                    for failed in cleanResult.failedItems {
                        print("   • \(failed.item.name): \(failed.error)")
                    }
                }
            }
        }
    }
    
    private func filterItems(_ items: [HomebrewCacheItem]) -> [HomebrewCacheItem] {
        switch type.lowercased() {
        case "cache":
            return items.filter { $0.type == .cache }
        case "downloads":
            return items.filter { $0.type == .downloads }
        case "logs":
            return items.filter { $0.type == .logs }
        case "old":
            return items.filter { $0.type == .oldVersions }
        default:
            return items
        }
    }
    
    private func runBrewCleanupCommand() async throws {
        print("Running 'brew cleanup --prune=all'...")
        
        let cleaner = HomebrewCleaner()
        let result = await cleaner.runBrewCleanup()
        
        if result.success {
            print("\n✅ brew cleanup completed successfully")
            if !result.output.isEmpty {
                print("\nOutput:")
                print(result.output)
            }
        } else {
            print("\n❌ brew cleanup failed")
            print(result.output)
        }
    }
}
