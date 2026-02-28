import Foundation
import AppKit

public struct SystemApp: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let path: URL
    public let size: Int64
    public let version: String?
    public let category: SystemAppCategory
    public let warningLevel: WarningLevel
    
    public init(
        name: String,
        bundleIdentifier: String,
        path: URL,
        size: Int64,
        version: String?,
        category: SystemAppCategory,
        warningLevel: WarningLevel
    ) {
        self.id = bundleIdentifier
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.size = size
        self.version = version
        self.category = category
        self.warningLevel = warningLevel
    }
}

public enum SystemAppCategory: String, Codable, CaseIterable {
    case creativity = "Creativity"
    case productivity = "Productivity"
    case developer = "Developer Tools"
    case other = "Other"
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .creativity: return "paintpalette.fill"
        case .productivity: return "doc.text.fill"
        case .developer: return "hammer.fill"
        case .other: return "app.fill"
        }
    }
}

public enum WarningLevel: String, Codable {
    case safe = "Safe"
    case caution = "Caution"
    case warning = "Warning"
    
    public var displayName: String { rawValue }
    
    public var color: String {
        switch self {
        case .safe: return "green"
        case .caution: return "orange"
        case .warning: return "red"
        }
    }
}

public struct SystemAppScanResult: Codable {
    public let apps: [SystemApp]
    public let totalSize: Int64
    public let scanDate: Date
    
    public init(apps: [SystemApp], scanDate: Date = Date()) {
        self.apps = apps
        self.scanDate = scanDate
        self.totalSize = apps.reduce(0) { $0 + $1.size }
    }
    
    public func apps(for category: SystemAppCategory) -> [SystemApp] {
        apps.filter { $0.category == category }
    }
}

public actor SystemAppScanner {
    private let removableApps: [(bundleId: String, name: String, category: SystemAppCategory, warningLevel: WarningLevel)] = [
        ("com.apple.garageband10", "GarageBand", .creativity, .safe),
        ("com.apple.iMovieApp", "iMovie", .creativity, .safe),
        ("com.apple.photos", "Photos", .creativity, .warning),
        ("com.apple.Music", "Music", .creativity, .caution),
        ("com.apple.Podcasts", "Podcasts", .creativity, .safe),
        ("com.apple.News", "News", .productivity, .safe),
        ("com.apple.Stocks", "Stocks", .productivity, .safe),
        ("com.apple.Maps", "Maps", .productivity, .caution),
        ("com.apple.FaceTime", "FaceTime", .productivity, .warning),
        ("com.apple.freeform", "Freeform", .productivity, .safe),
        ("com.apple.Keynote", "Keynote", .productivity, .caution),
        ("com.apple.Numbers", "Numbers", .productivity, .caution),
        ("com.apple.Pages", "Pages", .productivity, .caution),
        ("com.apple.dt.Xcode", "Xcode", .developer, .caution),
        ("com.apple.Safari", "Safari", .productivity, .warning),
        ("com.apple.mail", "Mail", .productivity, .warning),
        ("com.apple.Terminal", "Terminal", .developer, .warning),
        ("com.apple.TextEdit", "TextEdit", .productivity, .caution),
        ("com.apple.Preview", "Preview", .productivity, .warning),
        ("com.apple.finder", "Finder", .productivity, .warning)
    ]
    
    public init() {}
    
    public func scan() async -> SystemAppScanResult {
        var foundApps: [SystemApp] = []
        let fileManager = FileManager.default
        
        let searchPaths = [
            "/System/Applications",
            "/Applications"
        ]
        
        for (bundleId, name, category, warningLevel) in removableApps {
            var appPath: URL?
            var appSize: Int64 = 0
            var appVersion: String?
            
            for searchPath in searchPaths {
                let possiblePath = URL(fileURLWithPath: searchPath).appendingPathComponent("\(name).app")
                if fileManager.fileExists(atPath: possiblePath.path) {
                    appPath = possiblePath
                    break
                }
            }
            
            if let path = appPath {
                do {
                    appSize = try FileUtils.sizeOfItem(at: path)
                } catch {
                    appSize = 0
                }
                
                let bundle = Bundle(url: path)
                appVersion = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
                
                let app = SystemApp(
                    name: name,
                    bundleIdentifier: bundleId,
                    path: path,
                    size: appSize,
                    version: appVersion,
                    category: category,
                    warningLevel: warningLevel
                )
                foundApps.append(app)
            }
        }
        
        return SystemAppScanResult(apps: foundApps)
    }
    
    public func removeApp(_ app: SystemApp, dryRun: Bool) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        guard app.warningLevel != .warning else {
            throw FitMacError.systemItemProtected(item: app.name)
        }
        
        if await isAppRunning(bundleIdentifier: app.bundleIdentifier) {
            throw FitMacError.appRunning(appName: app.name)
        }
        
        if dryRun {
            let cleanupItem = CleanupItem(
                path: app.path,
                category: .temporary,
                size: app.size,
                isDirectory: true
            )
            deletedItems.append(cleanupItem)
            freedSpace += app.size
        } else {
            do {
                _ = try FileUtils.moveToTrash(at: app.path)
                
                let cleanupItem = CleanupItem(
                    path: app.path,
                    category: .temporary,
                    size: app.size,
                    isDirectory: true
                )
                deletedItems.append(cleanupItem)
                freedSpace += app.size
                
                try await forgetPackageReceipt(bundleId: app.bundleIdentifier)
                
            } catch let error as FitMacError {
                throw error
            } catch {
                let cleanupItem = CleanupItem(
                    path: app.path,
                    category: .temporary,
                    size: app.size,
                    isDirectory: true
                )
                failedItems.append(FailedItem(item: cleanupItem, error: error.localizedDescription))
            }
        }
        
        return CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: freedSpace
        )
    }
    
    private func isAppRunning(bundleIdentifier: String) async -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }
    
    private func forgetPackageReceipt(bundleId: String) async throws {
        let protectedPrefixes = [
            "com.apple.",
            "com.microsoft.",
            "com.google.",
            "org.mozilla."
        ]
        
        for prefix in protectedPrefixes {
            if bundleId.hasPrefix(prefix) {
                return
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        process.arguments = ["--pkg-info", bundleId]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return
            }
            
            let forgetProcess = Process()
            forgetProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
            forgetProcess.arguments = ["--forget", bundleId, "--volume", "/"]
            forgetProcess.standardOutput = FileHandle.nullDevice
            forgetProcess.standardError = FileHandle.nullDevice
            
            try forgetProcess.run()
            forgetProcess.waitUntilExit()
        } catch {
            return
        }
    }
}
