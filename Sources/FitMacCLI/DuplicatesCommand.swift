import ArgumentParser
import Foundation
import FitMacCore

struct DuplicatesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "duplicates",
        abstract: "Find and manage duplicate files"
    )
    
    @Flag(name: .long, help: "Scan for duplicate files")
    var scan = false
    
    @Option(name: .shortAndLong, help: "Minimum file size in MB (default: 1)")
    var min: Int = 1
    
    @Option(name: .shortAndLong, help: "Maximum files to scan (default: 5000)")
    var maxFiles: Int = 5000
    
    @Option(name: .shortAndLong, help: "Path to scan (default: home directory)")
    var path: String?
    
    @Flag(name: .long, help: "Delete all duplicates (keep first in each group)")
    var clean = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    mutating func run() async throws {
        let scanner = DuplicateScanner()
        let searchPath = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: NSHomeDirectory())
        let minSizeBytes = Int64(min) * 1024 * 1024
        
        print("Scanning for duplicate files...")
        print("Path: \(searchPath.path)")
        print("Minimum size: \(min) MB")
        print("")
        
        var scannedCount = 0
        let result = try await scanner.scan(
            paths: [searchPath],
            minSize: minSizeBytes,
            maxFiles: maxFiles
        ) { count in
            if count - scannedCount >= 100 {
                scannedCount = count
                print("\rScanned: \(count) files", terminator: "")
            }
        }
        
        print("\rScanned: \(result.totalFiles) files in \(result.groups.count) duplicate groups")
        
        if result.groups.isEmpty {
            print("\n✅ No duplicate files found.")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              Duplicate Files Found                       ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for (index, group) in result.groups.prefix(20).enumerated() {
            print("║ Group \(index + 1): \(group.files.count) files × \(SizeFormatter.format(group.fileSize))")
            print("║   Wasted: \(SizeFormatter.format(group.wastage))")
            for file in group.files.prefix(3) {
                print("║   • \(shortenPath(file.path.path))")
            }
            if group.files.count > 3 {
                print("║   ... and \(group.files.count - 3) more")
            }
            print("║")
        }
        
        if result.groups.count > 20 {
            print("║ ... and \(result.groups.count - 20) more groups")
        }
        
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(result.groups.count) groups, \(SizeFormatter.format(result.totalWastage)) wasted space")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            let filesToDelete = result.groups.flatMap { group in
                Array(group.files.dropFirst())
            }
            
            let totalSize = filesToDelete.reduce(0) { $0 + $1.size }
            
            print("\n⚠️  This will delete \(filesToDelete.count) duplicate files (\(SizeFormatter.format(totalSize)))")
            print("Files will be moved to Trash.")
            
            if !force {
                print("Continue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = DuplicateCleaner()
            let cleanResult = try await cleaner.clean(files: filesToDelete, dryRun: false)
            
            print("\n✅ Moved \(cleanResult.deletedItems.count) files to Trash")
            print("   Freed: \(SizeFormatter.format(cleanResult.freedSpace))")
            
            if !cleanResult.failedItems.isEmpty {
                print("\n❌ Failed to delete \(cleanResult.failedItems.count) files:")
                for failed in cleanResult.failedItems {
                    print("   • \(failed.item.path.lastPathComponent): \(failed.error)")
                }
            }
        }
    }
}
