import Foundation

public enum iTunesJunkCategory: String, CaseIterable, Codable {
    case iOSBackup = "iOS Device Backups"
    case podcastDownloads = "Podcast Downloads"
    case oldMobileApps = "Old Mobile Apps"
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .iOSBackup: return "iphone"
        case .podcastDownloads: return "mic.fill"
        case .oldMobileApps: return "app.fill"
        }
    }
}

public struct iTunesJunkItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let category: iTunesJunkCategory
    public let size: Int64
    public let isDirectory: Bool
    public let modifiedDate: Date?
    public let details: String?
    
    public init(name: String, path: URL, category: iTunesJunkCategory, size: Int64, isDirectory: Bool, modifiedDate: Date? = nil, details: String? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.category = category
        self.size = size
        self.isDirectory = isDirectory
        self.modifiedDate = modifiedDate
        self.details = details
    }
}

public struct iTunesJunkScanResult: Codable {
    public let items: [iTunesJunkItem]
    public let totalSize: Int64
    public let scanDate: Date
    public let categories: [iTunesJunkCategory: Int64]
    
    public init(items: [iTunesJunkItem], scanDate: Date = Date()) {
        self.items = items
        self.scanDate = scanDate
        self.totalSize = items.reduce(0) { $0 + $1.size }
        var cats: [iTunesJunkCategory: Int64] = [:]
        for item in items {
            cats[item.category, default: 0] += item.size
        }
        self.categories = cats
    }
    
    public func items(for category: iTunesJunkCategory) -> [iTunesJunkItem] {
        items.filter { $0.category == category }
    }
}

public actor iTunesScanner {
    public init() {}
    
    public func scan() async throws -> iTunesJunkScanResult {
        var items: [iTunesJunkItem] = []
        
        items.append(contentsOf: await scaniOSBackups())
        items.append(contentsOf: await scanPodcastDownloads())
        items.append(contentsOf: await scanOldMobileApps())
        
        return iTunesJunkScanResult(items: items)
    }
    
    private func scaniOSBackups() async -> [iTunesJunkItem] {
        var items: [iTunesJunkItem] = []
        let fileManager = FileManager.default
        
        let backupPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("MobileSync")
            .appendingPathComponent("Backup")
        
        guard fileManager.fileExists(atPath: backupPath.path) else { return items }
        
        do {
            let backupDirs = try fileManager.contentsOfDirectory(
                at: backupPath,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for backupDir in backupDirs {
                guard try FileUtils.isDirectory(at: backupDir) else { continue }
                
                do {
                    let size = try FileUtils.sizeOfItem(at: backupDir)
                    guard size > 0 else { continue }
                    
                    let modifiedDate = try? FileUtils.modifiedDate(at: backupDir)
                    let backupName = backupDir.lastPathComponent
                    
                    var deviceName: String? = nil
                    let infoPlistPath = backupDir.appendingPathComponent("Info.plist")
                    if let plistData = try? Data(contentsOf: infoPlistPath),
                       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                       let deviceNames = plist["Device Name"] as? [String: Any] {
                        deviceName = deviceNames["Display Name"] as? String
                    } else if let plist = try? PropertyListSerialization.propertyList(from: try Data(contentsOf: infoPlistPath), options: [], format: nil) as? [String: Any] {
                        deviceName = plist["Display Name"] as? String ?? plist["Device Name"] as? String
                    }
                    
                    let displayName = deviceName ?? "iOS Device"
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    let dateStr = modifiedDate.map { dateFormatter.string(from: $0) } ?? "Unknown date"
                    
                    items.append(iTunesJunkItem(
                        name: "\(displayName) Backup",
                        path: backupDir,
                        category: .iOSBackup,
                        size: size,
                        isDirectory: true,
                        modifiedDate: modifiedDate,
                        details: "Last backup: \(dateStr)"
                    ))
                } catch {
                    continue
                }
            }
        } catch {
            return items
        }
        
        return items
    }
    
    private func scanPodcastDownloads() async -> [iTunesJunkItem] {
        var items: [iTunesJunkItem] = []
        let fileManager = FileManager.default
        
        let podcastPaths = [
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Group Containers")
                .appendingPathComponent("243LU875E5.groups.com.apple.podcasts")
                .appendingPathComponent("Library")
                .appendingPathComponent("Cache"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Caches")
                .appendingPathComponent("com.apple.podcasts")
        ]
        
        for path in podcastPaths {
            guard fileManager.fileExists(atPath: path.path) else { continue }
            
            do {
                let size = try FileUtils.sizeOfItem(at: path)
                guard size > 0 else { continue }
                
                let modifiedDate = try? FileUtils.modifiedDate(at: path)
                
                items.append(iTunesJunkItem(
                    name: "Podcast Cache",
                    path: path,
                    category: .podcastDownloads,
                    size: size,
                    isDirectory: true,
                    modifiedDate: modifiedDate,
                    details: "Downloaded podcast episodes"
                ))
            } catch {
                continue
            }
        }
        
        return items
    }
    
    private func scanOldMobileApps() async -> [iTunesJunkItem] {
        var items: [iTunesJunkItem] = []
        let fileManager = FileManager.default
        
        let mobileAppsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Music")
            .appendingPathComponent("iTunes")
            .appendingPathComponent("Mobile Applications")
        
        guard fileManager.fileExists(atPath: mobileAppsPath.path) else { return items }
        
        do {
            let appFiles = try fileManager.contentsOfDirectory(
                at: mobileAppsPath,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var totalSize: Int64 = 0
            var appCount = 0
            
            for appFile in appFiles {
                guard appFile.pathExtension == "ipa" else { continue }
                
                do {
                    let resourceValues = try appFile.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                        appCount += 1
                    }
                } catch {
                    continue
                }
            }
            
            if totalSize > 0 {
                items.append(iTunesJunkItem(
                    name: "Old iOS Apps",
                    path: mobileAppsPath,
                    category: .oldMobileApps,
                    size: totalSize,
                    isDirectory: true,
                    details: "\(appCount) .ipa files found"
                ))
            }
        } catch {
            return items
        }
        
        return items
    }
}

public actor iTunesJunkCleaner {
    public init() {}
    
    public func clean(items: [iTunesJunkItem], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for item in items {
            do {
                if dryRun {
                    let cleanupItem = CleanupItem(
                        path: item.path,
                        category: .temporary,
                        size: item.size,
                        isDirectory: item.isDirectory
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                } else {
                    _ = try FileUtils.moveToTrash(at: item.path)
                    let cleanupItem = CleanupItem(
                        path: item.path,
                        category: .temporary,
                        size: item.size,
                        isDirectory: item.isDirectory
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += item.size
                }
            } catch {
                let cleanupItem = CleanupItem(
                    path: item.path,
                    category: .temporary,
                    size: item.size,
                    isDirectory: item.isDirectory
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
