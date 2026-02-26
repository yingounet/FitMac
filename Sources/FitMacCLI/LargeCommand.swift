import ArgumentParser
import Foundation
import FitMacCore

struct LargeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "large",
        abstract: "Find large files"
    )
    
    @Option(name: .shortAndLong, help: "Path to scan (default: user home)")
    var path: String?
    
    @Option(name: .shortAndLong, help: "Minimum file size (e.g., 100MB, 1GB)")
    var min: String = "100MB"
    
    @Option(name: .shortAndLong, help: "Sort by: size or date")
    var sort: String = "size"
    
    @Option(name: .shortAndLong, help: "Maximum number of results")
    var limit: Int = 20
    
    @Flag(name: .shortAndLong, help: "Move selected files to trash")
    var delete = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation")
    var force = false
    
    mutating func run() async throws {
        let scanPath = path.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser
        
        let minBytes = PathUtils.parseSize(min)
        
        print("Scanning for files larger than \(min) in \(shortenPath(scanPath.path))...")
        
        var files: [LargeFile] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: scanPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .typeIdentifierKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError("Unable to scan directory")
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey, .typeIdentifierKey, .isDirectoryKey
                ])
                
                guard resourceValues.isDirectory != true else { continue }
                
                let size = Int64(resourceValues.fileSize ?? 0)
                guard size >= minBytes else { continue }
                
                let modifiedDate = resourceValues.contentModificationDate
                let fileType = resourceValues.typeIdentifier ?? "public.data"
                
                files.append(LargeFile(
                    path: fileURL,
                    size: size,
                    modifiedDate: modifiedDate,
                    fileType: fileType
                ))
            } catch {
                continue
            }
        }
        
        if sort.lowercased() == "size" {
            files.sort { $0.size > $1.size }
        } else {
            files.sort { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
        }
        
        let limitedFiles = Array(files.prefix(limit))
        
        if limitedFiles.isEmpty {
            print("No files found larger than \(min).")
            return
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║                  Large Files Found                       ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for (index, file) in limitedFiles.enumerated() {
            let sizeStr = SizeFormatter.format(file.size)
            let shortPath = shortenPath(file.path.path)
            print("║ \(String(format: "%2d", index + 1)). \(pad(sizeStr, to: 10)) \(pad(shortPath, to: 39))║")
        }
        
        let totalSize = limitedFiles.reduce(0) { $0 + $1.size }
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total: \(limitedFiles.count) files, \(pad(SizeFormatter.format(totalSize), to: 41))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        if delete {
            if !force {
                print("\n⚠️  This will move \(limitedFiles.count) files (\(SizeFormatter.format(totalSize))) to Trash")
                print("Continue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            print("\nMoving files to trash...")
            var successCount = 0
            var failedCount = 0
            
            for file in limitedFiles {
                do {
                    _ = try FileUtils.moveToTrash(at: file.path)
                    print("✅ \(shortenPath(file.path.path))")
                    successCount += 1
                } catch {
                    print("❌ \(shortenPath(file.path.path)): \(error.localizedDescription)")
                    failedCount += 1
                }
            }
            
            print("\n📊 Summary: \(successCount) moved, \(failedCount) failed")
            
            if successCount > 0 {
                let log = CleanupLog(
                    operation: "Large Files Cleanup (CLI)",
                    itemsDeleted: successCount,
                    freedSpace: totalSize,
                    details: limitedFiles.prefix(successCount).map { $0.path.path }
                )
                try? await CleanupLogger.shared.log(log)
            }
        }
    }
}
