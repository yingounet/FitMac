import ArgumentParser
import Foundation
import FitMacCore

struct LanguageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "language",
        abstract: "Scan and remove unused language files"
    )
    
    @Flag(name: .long, help: "Scan and display unused language files")
    var scan = false
    
    @Flag(name: .long, help: "Remove unused language files")
    var clean = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    mutating func run() async throws {
        let scanner = LanguageScanner()
        
        print("Scanning language files...")
        let result = try await scanner.scan()
        
        if result.items.isEmpty {
            print("No language files found.")
            return
        }
        
        let removable = result.removableItems
        
        if removable.isEmpty {
            print("\n✅ No unused language files found.")
            print("   Current language: \(result.currentLanguage)")
            print("   Total language files scanned: \(result.items.count)")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              Language Files Scan Results                 ║")
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Current Language: \(pad(result.currentLanguage, to: 38))║")
        print("║ Total Files Scanned: \(pad("\(result.items.count)", to: 36))║")
        print("║ Removable Files: \(pad("\(removable.count)", to: 40))║")
        print("║ Space to Free: \(pad(SizeFormatter.format(result.removableSize), to: 41))║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        let apps = Set(removable.map(\.appName)).sorted()
        for app in apps.prefix(10) {
            let appItems = removable.filter { $0.appName == app }
            let totalSize = appItems.reduce(0) { $0 + $1.size }
            let languages = appItems.map(\.languageCode).joined(separator: ", ")
            print("║ 📱 \(app)")
            print("║    Languages: \(pad(languages, to: 44))")
            print("║    Size: \(pad(SizeFormatter.format(totalSize), to: 49))")
        }
        
        if apps.count > 10 {
            print("║ ... and \(apps.count - 10) more apps")
        }
        
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if !force {
                print("\n⚠️  This will remove \(removable.count) language files")
                print("   Space to free: \(SizeFormatter.format(result.removableSize))")
                print("   Your current language (\(result.currentLanguage)) will be preserved.")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = LanguageCleaner()
            let cleanResult = try await cleaner.clean(items: removable, dryRun: false)
            
            print("\n✅ Removed \(cleanResult.deletedItems.count) language files")
            print("   Freed: \(SizeFormatter.format(cleanResult.freedSpace))")
            
            if !cleanResult.failedItems.isEmpty {
                print("\n❌ Failed to remove \(cleanResult.failedItems.count) files:")
                for failed in cleanResult.failedItems {
                    print("   • \(failed.item.path.lastPathComponent): \(failed.error)")
                }
            }
        }
    }
    
    private func pad(_ string: String, to length: Int) -> String {
        let padded = string.padding(toLength: length, withPad: " ", startingAt: 0)
        return String(padded.prefix(length))
    }
}
