import ArgumentParser
import Foundation
import FitMacCore

struct LoginItemsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "loginitems",
        abstract: "Manage login items and launch agents"
    )
    
    @Flag(name: .long, help: "List all login items")
    var list = false
    
    @Flag(name: .long, help: "Show only enabled items")
    var enabled = false
    
    @Flag(name: .long, help: "Show only disabled items")
    var disabled = false
    
    @Option(name: .shortAndLong, help: "Filter by type: agent, daemon, loginitem, all")
    var type: String = "all"
    
    @Option(name: .long, help: "Disable item by label")
    var disable: String?
    
    @Option(name: .long, help: "Enable item by label")
    var enable: String?
    
    @Option(name: .long, help: "Remove item by label")
    var remove: String?
    
    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false
    
    mutating func run() async throws {
        let scanner = LoginItemsScanner()
        let manager = LoginItemsManager()
        
        if let label = disable {
            try await toggleItem(label: label, enable: false, scanner: scanner, manager: manager)
            return
        }
        
        if let label = enable {
            try await toggleItem(label: label, enable: true, scanner: scanner, manager: manager)
            return
        }
        
        if let label = remove {
            try await removeItem(label: label, scanner: scanner, manager: manager)
            return
        }
        
        print("Scanning login items...")
        let result = await scanner.scan()
        
        if result.items.isEmpty {
            print("No login items found.")
            return
        }
        
        var filteredItems = filterItems(result.items)
        
        if enabled {
            filteredItems = filteredItems.filter { $0.isEnabled }
        }
        
        if disabled {
            filteredItems = filteredItems.filter { !$0.isEnabled }
        }
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║                  Login Items Scan Results                ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for itemType in LoginItemType.allCases {
            let items = filteredItems.filter { $0.itemType == itemType }
            if !items.isEmpty {
                print("║ \(itemType.displayName): \(pad("\(items.count) items", to: 46))║")
            }
        }
        
        print("╠══════════════════════════════════════════════════════════╣")
        print("║ Enabled: \(pad("\(result.enabledCount)", to: 47))║")
        print("║ Disabled: \(pad("\(result.disabledCount)", to: 46))║")
        print("╚══════════════════════════════════════════════════════════╝")
        
        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║                      Item Details                        ║")
        print("╠══════════════════════════════════════════════════════════╣")
        
        for item in filteredItems.prefix(20) {
            let status = item.isEnabled ? "✓" : "✗"
            let systemFlag = item.isSystemItem ? " [System]" : ""
            print("║ [\(status)] \(pad(item.name, to: 30))\(pad(item.itemType.displayName + systemFlag, to: 20))║")
            if let program = item.programPath {
                print("║     \(pad(shortenPath(program), to: 52))║")
            }
        }
        
        if filteredItems.count > 20 {
            print("║ ... and \(filteredItems.count - 20) more items                                  ║")
        }
        
        print("╚══════════════════════════════════════════════════════════╝")
    }
    
    private func filterItems(_ items: [LoginItem]) -> [LoginItem] {
        switch type.lowercased() {
        case "agent":
            return items.filter { $0.itemType == .launchAgent }
        case "daemon":
            return items.filter { $0.itemType == .launchDaemon }
        case "loginitem":
            return items.filter { $0.itemType == .loginItem }
        default:
            return items
        }
    }
    
    private func toggleItem(label: String, enable: Bool, scanner: LoginItemsScanner, manager: LoginItemsManager) async throws {
        let result = await scanner.scan()
        
        guard let item = result.items.first(where: { $0.label == label || $0.name == label }) else {
            print("❌ Item not found: \(label)")
            return
        }
        
        let action = enable ? "Enable" : "Disable"
        
        if !force {
            print("\(action) '\(item.name)'? [y/N]: ", terminator: "")
            guard readLine()?.lowercased() == "y" else {
                print("Cancelled.")
                return
            }
        }
        
        let toggleResult = await manager.toggle(item: item, enable: enable)
        
        if toggleResult.success {
            print("✅ \(action)d '\(item.name)'")
        } else {
            print("❌ Failed to \(action.lowercased()) '\(item.name)': \(toggleResult.error ?? "Unknown error")")
        }
    }
    
    private func removeItem(label: String, scanner: LoginItemsScanner, manager: LoginItemsManager) async throws {
        let result = await scanner.scan()
        
        guard let item = result.items.first(where: { $0.label == label || $0.name == label }) else {
            print("❌ Item not found: \(label)")
            return
        }
        
        if item.isSystemItem {
            print("❌ Cannot remove system item: \(item.name)")
            return
        }
        
        if !force {
            print("⚠️  This will remove '\(item.name)' and move its plist to trash.")
            print("Continue? [y/N]: ", terminator: "")
            guard readLine()?.lowercased() == "y" else {
                print("Cancelled.")
                return
            }
        }
        
        let removeResult = await manager.remove(item: item)
        
        if removeResult.success {
            print("✅ Removed '\(item.name)'")
        } else {
            print("❌ Failed to remove '\(item.name)': \(removeResult.error ?? "Unknown error")")
        }
    }
}
