import ArgumentParser
import Foundation
import FitMacCore

struct SystemJunkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "systemjunk",
        abstract: "Scan and clean system junk files"
    )
    
    @Flag(name: .long, help: "Scan and display system junk")
    var scan = false
    
    @Flag(name: .long, help: "Clean system junk files")
    var clean = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    @Option(name: .shortAndLong, help: "Filter by category: temp, broken, versions, leftovers, all")
    var category: String = "all"
    
    mutating func run() async throws {
        let scanner = SystemJunkScanner()
        
        print("Scanning system junk...")
        let result = try await scanner.scan()
        
        if result.items.isEmpty {
            print("No system junk found.")
            return
        }
        
        let filteredItems = filterItems(result.items)
        
        if filteredItems.isEmpty {
            print("No items found for selected category.")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              System Junk Scan Results                    ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for category in SystemJunkCategory.allCases {
            let items = filteredItems.filter { $0.category == category }
            if !items.isEmpty {
                let totalSize = items.reduce(0) { $0 + $1.size }
                print("║ \(category.displayName): \(pad(SizeFormatter.format(totalSize), to: 41))║")
                for item in items.prefix(5) {
                    let shortPath = PathUtils.shorten(item.path.path)
                    print("║   • \(pad(shortPath, to: 50))║")
                    if let desc = item.description {
                        print("║     \(pad(desc, to: 50))║")
                    }
                }
                if items.count > 5 {
                    print("║   ... and \(items.count - 5) more items                                 ║")
                }
            }
        }
        
        let totalSize = filteredItems.reduce(0) { $0 + $1.size }
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(pad(SizeFormatter.format(totalSize), to: 49))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if !force {
                print("\n⚠️  This will clean \(filteredItems.count) item(s)")
                print("   Space to free: \(SizeFormatter.format(totalSize))")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = SystemJunkCleaner()
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
    
    private func filterItems(_ items: [SystemJunkItem]) -> [SystemJunkItem] {
        switch category.lowercased() {
        case "temp":
            return items.filter { $0.category == .temporaryFiles }
        case "broken":
            return items.filter { $0.category == .brokenDownloads }
        case "versions":
            return items.filter { $0.category == .documentVersions }
        case "leftovers":
            return items.filter { $0.category == .systemLeftovers }
        default:
            return items
        }
    }
    
    private func pad(_ string: String, to length: Int) -> String {
        let padded = string.padding(toLength: length, withPad: " ", startingAt: 0)
        return String(padded.prefix(length))
    }
}
