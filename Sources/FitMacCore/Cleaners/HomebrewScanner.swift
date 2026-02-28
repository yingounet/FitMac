import Foundation

public struct HomebrewCacheItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let type: HomebrewItemType
    public let modifiedDate: Date?
    
    public init(name: String, path: URL, size: Int64, type: HomebrewItemType, modifiedDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.size = size
        self.type = type
        self.modifiedDate = modifiedDate
    }
}

public enum HomebrewItemType: String, Codable, CaseIterable {
    case cache = "Cache"
    case downloads = "Downloads"
    case oldVersions = "Old Versions"
    case logs = "Logs"
    case cellar = "Cellar"
    
    public var displayName: String { rawValue }
}

public struct HomebrewScanResult: Codable {
    public let items: [HomebrewCacheItem]
    public let totalSize: Int64
    public let scanDate: Date
    public let isHomebrewInstalled: Bool
    public let brewPath: String?
    
    public init(items: [HomebrewCacheItem], isHomebrewInstalled: Bool, brewPath: String?, scanDate: Date = Date()) {
        self.items = items
        self.scanDate = scanDate
        self.totalSize = items.reduce(0) { $0 + $1.size }
        self.isHomebrewInstalled = isHomebrewInstalled
        self.brewPath = brewPath
    }
    
    public func items(for type: HomebrewItemType) -> [HomebrewCacheItem] {
        items.filter { $0.type == type }
    }
    
    public func size(for type: HomebrewItemType) -> Int64 {
        items(for: type).reduce(0) { $0 + $1.size }
    }
}

public struct FailedHomebrewItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let item: HomebrewCacheItem
    public let error: String
    
    public init(item: HomebrewCacheItem, error: String) {
        self.id = UUID()
        self.item = item
        self.error = error
    }
}

public struct HomebrewCleanResult: Codable {
    public let cleanedItems: [HomebrewCacheItem]
    public let failedItems: [FailedHomebrewItem]
    public let freedSpace: Int64
    public let cleanDate: Date
    
    public init(cleanedItems: [HomebrewCacheItem], failedItems: [FailedHomebrewItem], freedSpace: Int64, cleanDate: Date = Date()) {
        self.cleanedItems = cleanedItems
        self.failedItems = failedItems
        self.freedSpace = freedSpace
        self.cleanDate = cleanDate
    }
}

public actor HomebrewScanner {
    public init() {}
    
    public func checkHomebrewInstalled() async -> (installed: Bool, path: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["brew"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (true, path)
            }
        } catch {}
        
        return (false, nil)
    }
    
    public func scan() async -> HomebrewScanResult {
        let (installed, brewPath) = await checkHomebrewInstalled()
        
        guard installed else {
            return HomebrewScanResult(items: [], isHomebrewInstalled: false, brewPath: nil)
        }
        
        var items: [HomebrewCacheItem] = []
        
        if let homebrewPrefix = await getHomebrewPrefix() {
            items.append(contentsOf: await scanCacheDirectory(at: homebrewPrefix))
            items.append(contentsOf: await scanDownloadsDirectory(at: homebrewPrefix))
            items.append(contentsOf: await scanLogsDirectory(at: homebrewPrefix))
            items.append(contentsOf: await scanOldVersions(at: homebrewPrefix))
        }
        
        if let userCache = getUserCacheHomebrewPath() {
            items.append(contentsOf: await scanUserCacheHomebrew(at: userCache))
        }
        
        return HomebrewScanResult(items: items, isHomebrewInstalled: true, brewPath: brewPath)
    }
    
    private func getHomebrewPrefix() async -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["brew", "--prefix"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return path.map { URL(fileURLWithPath: $0) }
            }
        } catch {}
        
        let commonPaths = [
            "/opt/homebrew",
            "/usr/local/Homebrew",
            "/home/linuxbrew/.linuxbrew/Homebrew"
        ]
        
        for path in commonPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return nil
    }
    
    private func getUserCacheHomebrewPath() -> URL? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let userCachePath = homeDir.appendingPathComponent("Library/Caches/Homebrew")
        
        if FileManager.default.fileExists(atPath: userCachePath.path) {
            return userCachePath
        }
        return nil
    }
    
    private func scanCacheDirectory(at homebrewPrefix: URL) async -> [HomebrewCacheItem] {
        let cachePath = homebrewPrefix.appendingPathComponent("Caches")
        return await scanDirectory(at: cachePath, type: .cache)
    }
    
    private func scanDownloadsDirectory(at homebrewPrefix: URL) async -> [HomebrewCacheItem] {
        var items: [HomebrewCacheItem] = []
        
        let downloadsPath = homebrewPrefix.appendingPathComponent("downloads")
        items.append(contentsOf: await scanDirectory(at: downloadsPath, type: .downloads))
        
        let cellarPath = homebrewPrefix.appendingPathComponent("Cellar")
        if FileManager.default.fileExists(atPath: cellarPath.path) {
            items.append(contentsOf: await scanPartialDownloads(in: cellarPath))
        }
        
        return items
    }
    
    private func scanPartialDownloads(in cellarPath: URL) async -> [HomebrewCacheItem] {
        var items: [HomebrewCacheItem] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: cellarPath,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return items }
        
        let partialExtensions = [".incomplete", ".partial", ".downloading"]
        
        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            for ext in partialExtensions {
                if path.hasSuffix(ext) {
                    if let item = await createItem(at: fileURL, type: .downloads) {
                        items.append(item)
                    }
                    break
                }
            }
        }
        
        return items
    }
    
    private func scanLogsDirectory(at homebrewPrefix: URL) async -> [HomebrewCacheItem] {
        let logsPath = homebrewPrefix.appendingPathComponent("var/log")
        return await scanDirectory(at: logsPath, type: .logs)
    }
    
    private func scanOldVersions(at homebrewPrefix: URL) async -> [HomebrewCacheItem] {
        var items: [HomebrewCacheItem] = []
        let fileManager = FileManager.default
        let cellarPath = homebrewPrefix.appendingPathComponent("Cellar")
        
        guard fileManager.fileExists(atPath: cellarPath.path) else { return items }
        
        guard let packages = try? fileManager.contentsOfDirectory(at: cellarPath, includingPropertiesForKeys: nil) else {
            return items
        }
        
        for packageURL in packages {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: packageURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            guard let versions = try? fileManager.contentsOfDirectory(at: packageURL, includingPropertiesForKeys: nil) else {
                continue
            }
            
            if versions.count > 1 {
                let sortedVersions = versions.sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    return date1 > date2
                }
                
                for oldVersionURL in sortedVersions.dropFirst() {
                    if let item = await createItem(at: oldVersionURL, type: .oldVersions) {
                        items.append(item)
                    }
                }
            }
        }
        
        return items
    }
    
    private func scanUserCacheHomebrew(at path: URL) async -> [HomebrewCacheItem] {
        var items: [HomebrewCacheItem] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            let itemPath = fileURL.path
            
            if itemPath.contains("npm") || itemPath.contains("node") || itemPath.contains("yarn") {
                continue
            }
            
            if let item = await createItem(at: fileURL, type: .cache) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func scanDirectory(at directory: URL, type: HomebrewItemType) async -> [HomebrewCacheItem] {
        var items: [HomebrewCacheItem] = []
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directory.path) else { return items }
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            if let item = await createItem(at: fileURL, type: type) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func createItem(at url: URL, type: HomebrewItemType) async -> HomebrewCacheItem? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let size = try FileUtils.sizeOfItem(at: url)
            guard size > 0 else { return nil }
            
            let modifiedDate = try? FileUtils.modifiedDate(at: url)
            
            return HomebrewCacheItem(
                name: url.lastPathComponent,
                path: url,
                size: size,
                type: type,
                modifiedDate: modifiedDate
            )
        } catch {
            return nil
        }
    }
}

public actor HomebrewCleaner {
    public init() {}
    
    public func clean(items: [HomebrewCacheItem], dryRun: Bool = true) async -> HomebrewCleanResult {
        var cleanedItems: [HomebrewCacheItem] = []
        var failedItems: [FailedHomebrewItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            if dryRun {
                cleanedItems.append(item)
                freedSpace += item.size
            } else {
                do {
                    _ = try FileUtils.moveToTrash(at: item.path)
                    cleanedItems.append(item)
                    freedSpace += item.size
                } catch {
                    failedItems.append(FailedHomebrewItem(item: item, error: error.localizedDescription))
                }
            }
        }
        
        return HomebrewCleanResult(cleanedItems: cleanedItems, failedItems: failedItems, freedSpace: freedSpace)
    }
    
    public func runBrewCleanup() async -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["brew", "cleanup", "--prune=all"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
