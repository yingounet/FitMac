import ArgumentParser
import Foundation
import FitMacCore

struct SystemAppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "systemapps",
        abstract: "Manage removable system applications"
    )
    
    @Flag(name: .long, help: "List all removable system apps")
    var list = false
    
    @Option(name: .long, help: "Remove a specific app by name")
    var remove: String?
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    @Flag(name: .long, help: "Show only safe-to-remove apps")
    var safe = false
    
    mutating func run() async throws {
        let scanner = SystemAppScanner()
        
        print("Scanning system apps...")
        let result = await scanner.scan()
        
        if result.apps.isEmpty {
            print("No removable system apps found.")
            return
        }
        
        let appsToShow = safe ? result.apps.filter { $0.warningLevel == .safe } : result.apps
        
        if list || remove == nil {
            print("\n╔════════════════════════════════════════════════════════════╗")
            print("║              Removable System Apps                         ║")
            print("╠════════════════════════════════════════════════════════════╣")
            
            for category in SystemAppCategory.allCases {
                let appsInCategory = appsToShow.filter { $0.category == category }
                if !appsInCategory.isEmpty {
                    print("║ 【\(category.displayName)】")
                    for app in appsInCategory {
                        let warningIcon = warningIconFor(app.warningLevel)
                        let sizeStr = SizeFormatter.format(app.size)
                        print("║   \(warningIcon) \(app.name)")
                        print("║       Size: \(sizeStr)")
                        if let version = app.version {
                            print("║       Version: \(version)")
                        }
                    }
                    print("╠════════════════════════════════════════════════════════════╣")
                }
            }
            
            print("║ Total: \(appsToShow.count) apps, \(SizeFormatter.format(appsToShow.reduce(0) { $0 + $1.size }))")
            print("╚════════════════════════════════════════════════════════════╝")
            
            print("\nLegend: ✅ Safe | ⚠️ Caution | ❌ Not Recommended")
        }
        
        if let appName = remove {
            guard let app = result.apps.first(where: { $0.name.lowercased() == appName.lowercased() }) else {
                print("❌ App '\(appName)' not found in removable apps list.")
                return
            }
            
            if app.warningLevel == .warning {
                print("❌ Cannot remove '\(app.name)' - this app is marked as not recommended for removal.")
                return
            }
            
            if !force {
                print("\n⚠️  This will remove: \(app.name)")
                print("   Size: \(SizeFormatter.format(app.size))")
                print("   Path: \(app.path.path)")
                print("   Warning Level: \(app.warningLevel.displayName)")
                print("\nContinue? [y/N]: ", terminator: "")
                guard readLine()?.lowercased() == "y" else {
                    print("Cancelled.")
                    return
                }
            }
            
            print("\nRemoving \(app.name)...")
            let cleanupResult = try await scanner.removeApp(app, dryRun: false)
            
            if cleanupResult.deletedItems.isEmpty {
                print("❌ Failed to remove \(app.name)")
            } else {
                print("✅ Removed \(app.name)")
                print("   Freed: \(SizeFormatter.format(cleanupResult.freedSpace))")
                
                let log = CleanupLog(
                    operation: "System App Removal",
                    itemsDeleted: 1,
                    freedSpace: cleanupResult.freedSpace,
                    details: ["Removed: \(app.name)"]
                )
                try? await CleanupLogger.shared.log(log)
            }
        }
    }
    
    private func warningIconFor(_ level: WarningLevel) -> String {
        switch level {
        case .safe: return "✅"
        case .caution: return "⚠️"
        case .warning: return "❌"
        }
    }
}
