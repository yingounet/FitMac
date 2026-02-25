import ArgumentParser
import Foundation
import FitMacCore

struct UninstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Find and remove app leftovers"
    )
    
    @Argument(help: "Application name or bundle identifier")
    var appName: String
    
    @Flag(name: .shortAndLong, help: "Remove found leftovers")
    var clean = false
    
    @Flag(name: .long, help: "Actually delete files (default is dry-run)")
    var noDryRun = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation")
    var force = false
    
    private var dryRun: Bool { !noDryRun }
    
    mutating func run() async throws {
        print("Searching for leftovers of '\(appName)'...")
        
        let searchPaths = AppLeftoverPaths.searchPaths(for: appName)
        var foundItems: [CleanupItem] = []
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                let isDirectory = try FileUtils.isDirectory(at: path)
                let size = try FileUtils.sizeOfItem(at: path)
                let modifiedDate = try? FileUtils.modifiedDate(at: path)
                
                foundItems.append(CleanupItem(
                    path: path,
                    category: .appCache,
                    size: size,
                    isDirectory: isDirectory,
                    modifiedDate: modifiedDate
                ))
            }
        }
        
        if foundItems.isEmpty {
            print("No leftovers found for '\(appName)'.")
            return
        }
        
        let totalSize = foundItems.reduce(0) { $0 + $1.size }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║                App Leftovers Found                       ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for item in foundItems {
            let sizeStr = SizeFormatter.format(item.size)
            print("║ • \(pad(sizeStr, to: 10)) \(pad(shortenPath(item.path.path), to: 41))║")
        }
        
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(foundItems.count) items, \(pad(SizeFormatter.format(totalSize), to: 42))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if dryRun {
                print("\n[DRY-RUN] Would remove \(foundItems.count) items, freeing \(SizeFormatter.format(totalSize))")
            } else {
                if !force {
                    print("\n⚠️  This will delete \(foundItems.count) items (\(SizeFormatter.format(totalSize)))")
                    print("Continue? [y/N]: ", terminator: "")
                    guard readLine()?.lowercased() == "y" else {
                        print("Cancelled.")
                        return
                    }
                }
                
                for item in foundItems {
                    do {
                        _ = try FileUtils.moveToTrash(at: item.path)
                        print("✅ Moved to trash: \(item.path.lastPathComponent)")
                    } catch {
                        print("❌ Failed: \(item.path.lastPathComponent) - \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
