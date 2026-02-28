import Foundation
import ServiceManagement

public struct LoginItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let label: String
    public let path: URL
    public let programPath: String?
    public let arguments: [String]
    public let runAtLoad: Bool
    public let isEnabled: Bool
    public let itemType: LoginItemType
    public let isSystemItem: Bool
    public let bundleIdentifier: String?
    
    public init(
        name: String,
        label: String,
        path: URL,
        programPath: String?,
        arguments: [String],
        runAtLoad: Bool,
        isEnabled: Bool,
        itemType: LoginItemType,
        isSystemItem: Bool,
        bundleIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.label = label
        self.path = path
        self.programPath = programPath
        self.arguments = arguments
        self.runAtLoad = runAtLoad
        self.isEnabled = isEnabled
        self.itemType = itemType
        self.isSystemItem = isSystemItem
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum LoginItemType: String, Codable, CaseIterable {
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case loginItem = "Login Item"
    
    public var displayName: String { rawValue }
}

public struct LoginItemsScanResult: Codable {
    public let items: [LoginItem]
    public let scanDate: Date
    
    public init(items: [LoginItem], scanDate: Date = Date()) {
        self.items = items
        self.scanDate = scanDate
    }
    
    public func items(for type: LoginItemType) -> [LoginItem] {
        items.filter { $0.itemType == type }
    }
    
    public var enabledCount: Int {
        items.filter { $0.isEnabled }.count
    }
    
    public var disabledCount: Int {
        items.filter { !$0.isEnabled }.count
    }
}

public struct LoginItemToggleResult: Codable {
    public let item: LoginItem
    public let success: Bool
    public let error: String?
    
    public init(item: LoginItem, success: Bool, error: String? = nil) {
        self.item = item
        self.success = success
        self.error = error
    }
}

public actor LoginItemsScanner {
    public init() {}
    
    public func scan() async -> LoginItemsScanResult {
        var items: [LoginItem] = []
        
        items.append(contentsOf: await scanLaunchAgents())
        items.append(contentsOf: await scanLaunchDaemons())
        items.append(contentsOf: await scanLoginItems())
        
        return LoginItemsScanResult(items: items)
    }
    
    private func scanLaunchAgents() async -> [LoginItem] {
        var items: [LoginItem] = []
        
        let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        items.append(contentsOf: scanPlistDirectory(at: userAgentsPath, type: .launchAgent, isSystemItem: false))
        
        let systemAgentsPath = URL(fileURLWithPath: "/Library/LaunchAgents")
        items.append(contentsOf: scanPlistDirectory(at: systemAgentsPath, type: .launchAgent, isSystemItem: true))
        
        return items
    }
    
    private func scanLaunchDaemons() async -> [LoginItem] {
        let daemonsPath = URL(fileURLWithPath: "/Library/LaunchDaemons")
        return scanPlistDirectory(at: daemonsPath, type: .launchDaemon, isSystemItem: true)
    }
    
    private func scanPlistDirectory(at directory: URL, type: LoginItemType, isSystemItem: Bool) -> [LoginItem] {
        var items: [LoginItem] = []
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directory.path) else { return items }
        
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return items
        }
        
        for fileURL in contents {
            guard fileURL.pathExtension == "plist" else { continue }
            
            if let item = parseLaunchPlist(at: fileURL, type: type, isSystemItem: isSystemItem) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func parseLaunchPlist(at url: URL, type: LoginItemType, isSystemItem: Bool) -> LoginItem? {
        guard let plistData = try? Data(contentsOf: url) else { return nil }
        
        var plist: [String: Any]?
        if #available(macOS 13, *) {
            plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        } else {
            plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        }
        
        guard let dict = plist else { return nil }
        
        let label = dict["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let programPath = dict["Program"] as? String
        let programArguments = dict["ProgramArguments"] as? [String] ?? []
        let runAtLoad = dict["RunAtLoad"] as? Bool ?? false
        
        let name = URL(fileURLWithPath: programPath ?? url.path).deletingPathExtension().lastPathComponent
        
        let jobDomain = getJobDomain(for: label)
        let isEnabled = jobDomain != nil
        
        return LoginItem(
            name: name,
            label: label,
            path: url,
            programPath: programPath,
            arguments: programArguments,
            runAtLoad: runAtLoad,
            isEnabled: isEnabled,
            itemType: type,
            isSystemItem: isSystemItem
        )
    }
    
    private func getJobDomain(for label: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())/\(label)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? "gui/\(getuid())" : nil
        } catch {
            return nil
        }
    }
    
    private func scanLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []
        
        if #available(macOS 13, *) {
            let loginItems = SMAppService.loginItems
            for item in loginItems {
                if let loginItem = createLoginItem(from: item) {
                    items.append(loginItem)
                }
            }
        }
        
        let loginItemsPath = URL(fileURLWithPath: "/Library/Application Support/com.apple.backgroundtaskmanagementagent/Downloads.plist")
        if let legacyItems = parseLegacyLoginItems(at: loginItemsPath) {
            items.append(contentsOf: legacyItems)
        }
        
        return items
    }
    
    @available(macOS 13, *)
    private func createLoginItem(from service: SMAppService) -> LoginItem? {
        let name = service.bundle?.bundleIdentifier ?? "Unknown"
        
        return LoginItem(
            name: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent,
            label: name,
            path: service.bundle?.bundleURL ?? URL(fileURLWithPath: "/"),
            programPath: service.bundle?.executableURL?.path,
            arguments: [],
            runAtLoad: true,
            isEnabled: service.status == .enabled,
            itemType: .loginItem,
            isSystemItem: false,
            bundleIdentifier: service.bundle?.bundleIdentifier
        )
    }
    
    private func parseLegacyLoginItems(at path: URL) -> [LoginItem]? {
        guard let data = try? Data(contentsOf: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let items = plist["items"] as? [[String: Any]] else {
            return nil
        }
        
        return items.compactMap { itemDict -> LoginItem? in
            guard let name = itemDict["Name"] as? String,
                  let url = itemDict["URL"] as? URL ?? (itemDict["URLString"] as? String).flatMap({ URL(string: $0) }) else {
                return nil
            }
            
            return LoginItem(
                name: name,
                label: name,
                path: url,
                programPath: url.path,
                arguments: [],
                runAtLoad: true,
                isEnabled: !(itemDict["Disabled"] as? Bool ?? false),
                itemType: .loginItem,
                isSystemItem: false
            )
        }
    }
}

public actor LoginItemsManager {
    public init() {}
    
    public func toggle(item: LoginItem, enable: Bool) async -> LoginItemToggleResult {
        if item.itemType == .loginItem {
            return await toggleLoginItem(item: item, enable: enable)
        } else {
            return await toggleLaunchAgent(item: item, enable: enable)
        }
    }
    
    @available(macOS 13, *)
    private func toggleLoginItem(item: LoginItem, enable: Bool) async -> LoginItemToggleResult {
        guard let bundleId = item.bundleIdentifier else {
            return LoginItemToggleResult(item: item, success: false, error: "No bundle identifier")
        }
        
        let service = SMAppService.loginItem(identifier: bundleId)
        
        do {
            if enable {
                try service.register()
            } else {
                try service.unregister()
            }
            return LoginItemToggleResult(item: item, success: true)
        } catch {
            return LoginItemToggleResult(item: item, success: false, error: error.localizedDescription)
        }
    }
    
    private func toggleLoginItem(item: LoginItem, enable: Bool) async -> LoginItemToggleResult {
        if #available(macOS 13, *) {
            guard let bundleId = item.bundleIdentifier else {
                return LoginItemToggleResult(item: item, success: false, error: "No bundle identifier")
            }
            
            let service = SMAppService.loginItem(identifier: bundleId)
            
            do {
                if enable {
                    try service.register()
                } else {
                    try service.unregister()
                }
                return LoginItemToggleResult(item: item, success: true)
            } catch {
                return LoginItemToggleResult(item: item, success: false, error: error.localizedDescription)
            }
        } else {
            return toggleLaunchAgent(item: item, enable: enable)
        }
    }
    
    private func toggleLaunchAgent(item: LoginItem, enable: Bool) async -> LoginItemToggleResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        
        if enable {
            process.arguments = ["load", "-w", item.path.path]
        } else {
            process.arguments = ["unload", "-w", item.path.path]
        }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                return LoginItemToggleResult(item: item, success: true)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                return LoginItemToggleResult(item: item, success: false, error: output)
            }
        } catch {
            return LoginItemToggleResult(item: item, success: false, error: error.localizedDescription)
        }
    }
    
    public func remove(item: LoginItem) async -> LoginItemToggleResult {
        guard !item.isSystemItem else {
            return LoginItemToggleResult(item: item, success: false, error: "Cannot remove system items")
        }
        
        if item.isEnabled {
            let disableResult = await toggle(item: item, enable: false)
            if !disableResult.success {
                return disableResult
            }
        }
        
        do {
            _ = try FileUtils.moveToTrash(at: item.path)
            return LoginItemToggleResult(item: item, success: true)
        } catch {
            return LoginItemToggleResult(item: item, success: false, error: error.localizedDescription)
        }
    }
}
