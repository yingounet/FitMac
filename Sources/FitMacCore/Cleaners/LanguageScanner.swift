import Foundation

public struct LanguageFile: Identifiable, Codable, Hashable {
    public let id: UUID
    public let appName: String
    public let appPath: URL
    public let languageCode: String
    public let lprojPath: URL
    public let size: Int64
    public let isCurrentLanguage: Bool
    
    public init(appName: String, appPath: URL, languageCode: String, lprojPath: URL, size: Int64, isCurrentLanguage: Bool) {
        self.id = UUID()
        self.appName = appName
        self.appPath = appPath
        self.languageCode = languageCode
        self.lprojPath = lprojPath
        self.size = size
        self.isCurrentLanguage = isCurrentLanguage
    }
}

public struct LanguageScanResult: Codable {
    public let items: [LanguageFile]
    public let totalSize: Int64
    public let scanDate: Date
    public let currentLanguage: String
    
    public init(items: [LanguageFile], currentLanguage: String, scanDate: Date = Date()) {
        self.items = items
        self.currentLanguage = currentLanguage
        self.scanDate = scanDate
        self.totalSize = items.filter { !$0.isCurrentLanguage }.reduce(0) { $0 + $1.size }
    }
    
    public var removableItems: [LanguageFile] {
        items.filter { !$0.isCurrentLanguage }
    }
    
    public var removableSize: Int64 {
        removableItems.reduce(0) { $0 + $1.size }
    }
}

public actor LanguageScanner {
    public init() {}
    
    public func scan() async throws -> LanguageScanResult {
        let currentLanguage = getCurrentLanguage()
        var items: [LanguageFile] = []
        
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]
        
        for directory in appDirectories {
            let apps = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            
            for appURL in apps ?? [] {
                guard appURL.pathExtension == "app" else { continue }
                let appItems = await scanAppBundle(at: appURL, currentLanguage: currentLanguage)
                items.append(contentsOf: appItems)
            }
        }
        
        return LanguageScanResult(items: items, currentLanguage: currentLanguage)
    }
    
    private func getCurrentLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let locale = Locale(identifier: preferredLanguage)
        
        if let languageCode = locale.language.languageCode?.identifier {
            let script = locale.language.script?.identifier
            if let script = script {
                return "\(languageCode)-\(script)"
            }
            return languageCode
        }
        return "en"
    }
    
    private func scanAppBundle(at appURL: URL, currentLanguage: String) async -> [LanguageFile] {
        let fileManager = FileManager.default
        var items: [LanguageFile] = []
        
        let resourcesPath = appURL.appendingPathComponent("Contents").appendingPathComponent("Resources")
        
        guard fileManager.isReadableFile(atPath: resourcesPath.path) else {
            return items
        }
        
        let contents = try? fileManager.contentsOfDirectory(
            at: resourcesPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        
        for itemURL in contents ?? [] {
            let pathExtension = itemURL.pathExtension
            guard pathExtension == "lproj" else { continue }
            
            let languageCode = itemURL.deletingPathExtension().lastPathComponent
            
            let isCurrentLanguage = isMatchingLanguage(languageCode, current: currentLanguage)
            
            do {
                let size = try FileUtils.sizeOfItem(at: itemURL)
                let appName = appURL.deletingPathExtension().lastPathComponent
                
                items.append(LanguageFile(
                    appName: appName,
                    appPath: appURL,
                    languageCode: languageCode,
                    lprojPath: itemURL,
                    size: size,
                    isCurrentLanguage: isCurrentLanguage
                ))
            } catch {
                continue
            }
        }
        
        return items
    }
    
    private func isMatchingLanguage(_ code: String, current: String) -> Bool {
        let normalizedCode = code.lowercased()
        let normalizedCurrent = current.lowercased()
        
        if normalizedCode == normalizedCurrent {
            return true
        }
        
        if normalizedCode == "en" && normalizedCurrent.hasPrefix("en") {
            return true
        }
        if normalizedCode == "base" {
            return true
        }
        if normalizedCurrent.hasPrefix("zh") {
            if normalizedCode == "zh-hans" && normalizedCurrent.contains("hans") {
                return true
            }
            if normalizedCode == "zh-hant" && normalizedCurrent.contains("hant") {
                return true
            }
            if normalizedCode == "zh-cn" && normalizedCurrent.contains("hans") {
                return true
            }
            if normalizedCode == "zh-tw" && normalizedCurrent.contains("hant") {
                return true
            }
        }
        
        let codePrefix = normalizedCode.components(separatedBy: "-").first ?? normalizedCode
        let currentPrefix = normalizedCurrent.components(separatedBy: "-").first ?? normalizedCurrent
        
        if codePrefix == currentPrefix && codePrefix.count >= 2 {
            return true
        }
        
        return false
    }
}

public actor LanguageCleaner {
    public init() {}
    
    public func clean(items: [LanguageFile], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            guard !item.isCurrentLanguage else { continue }
            
            do {
                if dryRun {
                    let cleanupItem = CleanupItem(
                        path: item.lprojPath,
                        category: .temporary,
                        size: item.size,
                        isDirectory: true
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                } else {
                    _ = try FileUtils.moveToTrash(at: item.lprojPath)
                    let cleanupItem = CleanupItem(
                        path: item.lprojPath,
                        category: .temporary,
                        size: item.size,
                        isDirectory: true
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                }
            } catch {
                let cleanupItem = CleanupItem(
                    path: item.lprojPath,
                    category: .temporary,
                    size: item.size,
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
}
