import ArgumentParser
import Foundation
import FitMacCore

struct CacheCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Scan and clean system/application caches"
    )
    
    @Flag(name: .long, help: "Scan and display cache files")
    var scan = false
    
    @Flag(name: .long, help: "Clean cache files")
    var clean = false
    
    @Flag(name: .long, help: "Actually delete files (default is dry-run)")
    var noDryRun = false
    
    @Option(name: .shortAndLong, help: "Filter by category: system, app, browser, dev, logs, temp, all")
    var category: String = "all"
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    private var dryRun: Bool { !noDryRun }
    
    mutating func run() async throws {
        let categories = parseCategories()
        let scanner = CacheScanner()
        
        print("Scanning cache files...")
        let result = try await scanner.scan(categories: categories)
        
        if result.items.isEmpty {
            print("No cache files found.")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║                  Cache Scan Results                      ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for category in CacheCategory.allCases where categories.contains(category) {
            let items = result.items(for: category)
            if !items.isEmpty {
                let totalSize = items.reduce(0) { $0 + $1.size }
                print("║ \(category.displayName): \(pad(SizeFormatter.format(totalSize), to: 42))║")
                for item in items.prefix(10) {
                    let shortPath = shortenPath(item.path.path)
                    print("║   • \(pad(shortPath, to: 50))║")
                }
                if items.count > 10 {
                    print("║   ... and \(items.count - 10) more items                                 ║")
                }
            }
        }
        
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(pad(SizeFormatter.format(result.totalSize), to: 49))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if dryRun {
                print("\n[DRY-RUN] Would clean \(result.items.count) items, freeing \(SizeFormatter.format(result.totalSize))")
            } else {
                if !force {
                    print("\n⚠️  This will delete \(result.items.count) items (\(SizeFormatter.format(result.totalSize)))")
                    print("Continue? [y/N]: ", terminator: "")
                    guard readLine()?.lowercased() == "y" else {
                        print("Cancelled.")
                        return
                    }
                }
                
                let cleaner = CacheCleaner()
                let cleanResult = try await cleaner.clean(items: result.items, dryRun: false)
                
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
    }
    
    private func parseCategories() -> [CacheCategory] {
        switch category.lowercased() {
        case "system":
            return [.systemCache]
        case "app":
            return [.appCache]
        case "browser":
            return [.browserCache]
        case "dev":
            return [.devCache]
        case "logs":
            return [.logs]
        case "temp":
            return [.temporary]
        default:
            return CacheCategory.allCases
        }
    }
}
