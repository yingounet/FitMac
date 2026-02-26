import Foundation

public struct TrashBin: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let volumeName: String
    public let isExternal: Bool
    
    public init(name: String, path: URL, size: Int64, volumeName: String, isExternal: Bool = false) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.size = size
        self.volumeName = volumeName
        self.isExternal = isExternal
    }
}

public struct TrashScanResult: Codable {
    public let bins: [TrashBin]
    public let totalSize: Int64
    public let scanDate: Date
    
    public init(bins: [TrashBin], scanDate: Date = Date()) {
        self.bins = bins
        self.scanDate = scanDate
        self.totalSize = bins.reduce(0) { $0 + $1.size }
    }
}

public struct FailedTrashBin: Identifiable, Codable, Hashable {
    public let id: UUID
    public let bin: TrashBin
    public let error: String
    
    public init(bin: TrashBin, error: String) {
        self.id = UUID()
        self.bin = bin
        self.error = error
    }
}

public struct TrashEmptyResult: Codable {
    public let emptiedBins: [TrashBin]
    public let failedBins: [FailedTrashBin]
    public let freedSpace: Int64
    public let emptyDate: Date
    
    public init(emptiedBins: [TrashBin], failedBins: [FailedTrashBin], freedSpace: Int64, emptyDate: Date = Date()) {
        self.emptiedBins = emptiedBins
        self.failedBins = failedBins
        self.freedSpace = freedSpace
        self.emptyDate = emptyDate
    }
}

public actor TrashScanner {
    public init() {}
    
    public func scan() async throws -> TrashScanResult {
        var bins: [TrashBin] = []
        
        if let userTrash = await scanUserTrash() {
            bins.append(userTrash)
        }
        
        let externalTrashes = await scanExternalTrashes()
        bins.append(contentsOf: externalTrashes)
        
        return TrashScanResult(bins: bins)
    }
    
    private func scanUserTrash() async -> TrashBin? {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let trashPath = homeDir.appendingPathComponent(".Trash")
        
        guard fileManager.fileExists(atPath: trashPath.path) else {
            return nil
        }
        
        do {
            let size = try FileUtils.sizeOfItem(at: trashPath)
            return TrashBin(
                name: "User Trash",
                path: trashPath,
                size: size,
                volumeName: "Macintosh HD",
                isExternal: false
            )
        } catch {
            return nil
        }
    }
    
    private func scanExternalTrashes() async -> [TrashBin] {
        let fileManager = FileManager.default
        var bins: [TrashBin] = []
        
        let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey], options: [])
        
        guard let volumes = volumeURLs else { return bins }
        
        for volumeURL in volumes {
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeNameKey, .volumeIsRemovableKey])
                guard let volumeName = resourceValues.volumeName,
                      resourceValues.volumeIsRemovable == true else {
                    continue
                }
                
                let trashPath = volumeURL.appendingPathComponent(".Trashes")
                
                guard fileManager.fileExists(atPath: trashPath.path) else {
                    continue
                }
                
                let uid = getuid()
                let userTrashPath = trashPath.appendingPathComponent(String(uid))
                
                if fileManager.fileExists(atPath: userTrashPath.path) {
                    let size = try FileUtils.sizeOfItem(at: userTrashPath)
                    if size > 0 {
                        bins.append(TrashBin(
                            name: "\(volumeName) Trash",
                            path: userTrashPath,
                            size: size,
                            volumeName: volumeName,
                            isExternal: true
                        ))
                    }
                } else if fileManager.isReadableFile(atPath: trashPath.path) {
                    let size = try FileUtils.sizeOfItem(at: trashPath)
                    if size > 0 {
                        bins.append(TrashBin(
                            name: "\(volumeName) Trash",
                            path: trashPath,
                            size: size,
                            volumeName: volumeName,
                            isExternal: true
                        ))
                    }
                }
            } catch {
                continue
            }
        }
        
        return bins
    }
}

public actor TrashCleaner {
    public init() {}
    
    public func empty(bin: TrashBin, dryRun: Bool = true) async throws -> Bool {
        if dryRun {
            return true
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bin.path.path) else {
            return true
        }
        
        let contents = try fileManager.contentsOfDirectory(at: bin.path, includingPropertiesForKeys: nil)
        
        for itemURL in contents {
            do {
                try fileManager.removeItem(at: itemURL)
            } catch {
                throw error
            }
        }
        
        return true
    }
    
    public func emptyAll(bins: [TrashBin], dryRun: Bool = true) async -> TrashEmptyResult {
        var emptiedBins: [TrashBin] = []
        var failedBins: [FailedTrashBin] = []
        var freedSpace: Int64 = 0
        
        for bin in bins {
            do {
                if try await empty(bin: bin, dryRun: dryRun) {
                    emptiedBins.append(bin)
                    freedSpace += bin.size
                }
            } catch {
                failedBins.append(FailedTrashBin(bin: bin, error: error.localizedDescription))
            }
        }
        
        return TrashEmptyResult(emptiedBins: emptiedBins, failedBins: failedBins, freedSpace: freedSpace)
    }
}
