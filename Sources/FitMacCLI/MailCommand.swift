import ArgumentParser
import Foundation
import FitMacCore

struct MailCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mail",
        abstract: "Scan and clean large mail attachments"
    )
    
    @Flag(name: .long, help: "List all large mail attachments")
    var list = false
    
    @Flag(name: .long, help: "Scan and display mail attachments")
    var scan = false
    
    @Flag(name: .long, help: "Remove selected mail attachments")
    var clean = false
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    @Option(name: .shortAndLong, help: "Minimum file size in KB (default: 100)")
    var minSize: Int64 = 100
    
    @Option(name: .shortAndLong, help: "Limit number of results")
    var limit: Int = 50
    
    mutating func run() async throws {
        let scanner = MailScanner(minSizeKB: minSize)
        
        print("Scanning mail attachments (min size: \(minSize)KB)...")
        let result = try await scanner.scan()
        
        if result.attachments.isEmpty {
            print("No large mail attachments found.")
            return
        }
        
        let limitedAttachments = Array(result.attachments.prefix(limit))
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║              Mail Attachments Scan Results               ║")
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Total Attachments: \(pad("\(result.attachments.count)", to: 36))║")
        print("║ Total Size: \(pad(SizeFormatter.format(result.totalSize), to: 44))║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for attachment in limitedAttachments {
            print("║ 📎 \(pad(attachment.filename, to: 51))║")
            print("║     Size: \(pad(SizeFormatter.format(attachment.size), to: 48))║")
            if let mailbox = attachment.mailbox {
                print("║     Mailbox: \(pad(mailbox, to: 46))║")
            }
            if let date = attachment.receivedDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                print("║     Date: \(pad(dateFormatter.string(from: date), to: 49))║")
            }
            print("╠══════════════════════════════════════════════════════════╣")
        }
        
        if result.attachments.count > limit {
            print("║ ... and \(result.attachments.count - limit) more attachments                             ║")
            print("╠══════════════════════════════════════════════════════════╣")
        }
        
        print("╚══════════════════════════════════════════════════════════╝")
        
        if clean {
            if !force {
                print("\n⚠️  This will remove \(result.attachments.count) attachment(s)")
                print("   Space to free: \(SizeFormatter.format(result.totalSize))")
                print("   ⚠️  Attachments will be moved to Trash, but original emails will remain.")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let cleaner = MailCleaner()
            let cleanResult = try await cleaner.clean(attachments: result.attachments, dryRun: false)
            
            print("\n✅ Removed \(cleanResult.deletedItems.count) attachment(s)")
            print("   Freed: \(SizeFormatter.format(cleanResult.freedSpace))")
            
            if !cleanResult.failedItems.isEmpty {
                print("\n❌ Failed to remove \(cleanResult.failedItems.count) item(s):")
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
