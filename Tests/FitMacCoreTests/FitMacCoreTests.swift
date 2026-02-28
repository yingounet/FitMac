import XCTest
@testable import FitMacCore

final class FitMacCoreTests: XCTestCase {
    
    func testSizeFormatter() {
        XCTAssertTrue(SizeFormatter.format(Int64(0)).contains("0"))
        XCTAssertTrue(SizeFormatter.format(Int64(1024)).contains("1"))
        XCTAssertTrue(SizeFormatter.format(Int64(1048576)).contains("1"))
        XCTAssertTrue(SizeFormatter.format(Int64(1073741824)).contains("1"))
    }
    
    func testSizeFormatterUInt64() {
        XCTAssertEqual(SizeFormatter.format(UInt64(1024)), SizeFormatter.format(Int64(1024)))
    }
    
    func testCacheCategory() {
        XCTAssertEqual(CacheCategory.systemCache.displayName, "System Cache")
        XCTAssertEqual(CacheCategory.appCache.displayName, "Application Cache")
        XCTAssertEqual(CacheCategory.browserCache.displayName, "Browser Cache")
        XCTAssertEqual(CacheCategory.devCache.displayName, "Developer Cache")
        XCTAssertEqual(CacheCategory.logs.displayName, "Logs")
        XCTAssertEqual(CacheCategory.temporary.displayName, "Temporary Files")
    }
    
    func testCacheCategoryAllCases() {
        XCTAssertEqual(CacheCategory.allCases.count, 6)
    }
    
    func testCleanupItem() {
        let item = CleanupItem(
            path: URL(fileURLWithPath: "/tmp/test"),
            category: .systemCache,
            size: 1024,
            isDirectory: false,
            modifiedDate: nil
        )
        
        XCTAssertEqual(item.size, 1024)
        XCTAssertEqual(item.category, .systemCache)
        XCTAssertFalse(item.isDirectory)
    }
    
    func testCleanupItemWithDirectory() {
        let item = CleanupItem(
            path: URL(fileURLWithPath: "/tmp/testdir"),
            category: .appCache,
            size: 2048,
            isDirectory: true,
            modifiedDate: Date()
        )
        
        XCTAssertTrue(item.isDirectory)
        XCTAssertEqual(item.category, .appCache)
        XCTAssertNotNil(item.modifiedDate)
    }
    
    func testScanResult() {
        let items = [
            CleanupItem(path: URL(fileURLWithPath: "/tmp/a"), category: .systemCache, size: 100),
            CleanupItem(path: URL(fileURLWithPath: "/tmp/b"), category: .systemCache, size: 200),
            CleanupItem(path: URL(fileURLWithPath: "/tmp/c"), category: .browserCache, size: 300),
        ]
        
        let result = ScanResult(items: items)
        
        XCTAssertEqual(result.totalSize, 600)
        XCTAssertEqual(result.items(for: .systemCache).count, 2)
        XCTAssertEqual(result.items(for: .browserCache).count, 1)
        XCTAssertEqual(result.categories[.systemCache], 300)
        XCTAssertEqual(result.categories[.browserCache], 300)
    }
    
    func testScanResultEmpty() {
        let result = ScanResult(items: [])
        XCTAssertEqual(result.totalSize, 0)
        XCTAssertTrue(result.items.isEmpty)
    }
    
    func testDiskStatus() {
        let status = DiskStatus(
            totalSpace: 1000,
            usedSpace: 750,
            availableSpace: 250,
            volumeName: "Test Volume"
        )
        
        XCTAssertEqual(status.totalSpace, 1000)
        XCTAssertEqual(status.usedSpace, 750)
        XCTAssertEqual(status.availableSpace, 250)
        XCTAssertEqual(status.usedPercentage, 75.0, accuracy: 0.01)
    }
    
    func testDiskStatusPercentage() {
        let status1 = DiskStatus(totalSpace: 100, usedSpace: 0, availableSpace: 100, volumeName: "Test")
        XCTAssertEqual(status1.usedPercentage, 0, accuracy: 0.01)
        
        let status2 = DiskStatus(totalSpace: 100, usedSpace: 100, availableSpace: 0, volumeName: "Test")
        XCTAssertEqual(status2.usedPercentage, 100, accuracy: 0.01)
    }
    
    func testCachePathsExpansion() {
        let expandedPath = CachePaths.expandedPath("~/Library/Caches")
        XCTAssertTrue(expandedPath.path.contains("Library/Caches"))
        XCTAssertFalse(expandedPath.path.hasPrefix("~"))
    }
    
    func testCachePathsSystemPaths() {
        let paths = CachePaths.systemCachePaths
        XCTAssertFalse(paths.isEmpty)
    }
    
    func testCachePathsBrowserPaths() {
        let paths = CachePaths.browserCachePaths
        XCTAssertFalse(paths.isEmpty)
        XCTAssertTrue(paths.contains { $0.path.contains("Safari") || $0.path.contains("Chrome") })
    }
    
    func testCachePathsDevPaths() {
        let paths = CachePaths.devCachePaths
        XCTAssertFalse(paths.isEmpty)
        XCTAssertTrue(paths.contains { $0.path.contains("Xcode") || $0.path.contains("npm") })
    }
    
    func testCachePathsAllPaths() {
        let allPaths = CachePaths.allCachePaths
        XCTAssertFalse(allPaths.isEmpty)
    }
    
    func testAppLeftoverPaths() {
        let paths = AppLeftoverPaths.searchPaths(for: "com.example.app")
        XCTAssertFalse(paths.isEmpty)
        
        let hasPreferencesPath = paths.contains { $0.path.contains("Preferences") }
        XCTAssertTrue(hasPreferencesPath)
    }
    
    func testAppLeftoverPathsContainsExpectedLocations() {
        let paths = AppLeftoverPaths.searchPaths(for: "com.test.app")
        let pathStrings = paths.map { $0.path }
        
        XCTAssertTrue(pathStrings.contains { $0.contains("Preferences") })
        XCTAssertTrue(pathStrings.contains { $0.contains("Application Support") })
        XCTAssertTrue(pathStrings.contains { $0.contains("Caches") })
        XCTAssertTrue(pathStrings.contains { $0.contains("Containers") })
        XCTAssertTrue(pathStrings.contains { $0.contains("Logs") })
    }
    
    func testFailedItem() {
        let item = CleanupItem(path: URL(fileURLWithPath: "/tmp/test"), category: .systemCache, size: 100)
        let failed = FailedItem(item: item, error: "Test error")
        
        XCTAssertEqual(failed.item.size, 100)
        XCTAssertEqual(failed.error, "Test error")
    }
    
    func testCleanupResult() {
        let deleted = [
            CleanupItem(path: URL(fileURLWithPath: "/tmp/a"), category: .systemCache, size: 100),
            CleanupItem(path: URL(fileURLWithPath: "/tmp/b"), category: .systemCache, size: 200),
        ]
        let failed: [FailedItem] = []
        
        let result = CleanupResult(deletedItems: deleted, failedItems: failed, freedSpace: 300)
        
        XCTAssertEqual(result.deletedItems.count, 2)
        XCTAssertEqual(result.freedSpace, 300)
        XCTAssertTrue(result.failedItems.isEmpty)
    }
    
    func testCleanupResultWithFailedItems() {
        let deleted = [CleanupItem(path: URL(fileURLWithPath: "/tmp/a"), category: .systemCache, size: 100)]
        let failedItems: [(CleanupItem, String)] = [
            (CleanupItem(path: URL(fileURLWithPath: "/tmp/b"), category: .systemCache, size: 200), "Access denied")
        ]
        
        let result = CleanupResult(deletedItems: deleted, failedItems: failedItems, freedSpace: 100)
        
        XCTAssertEqual(result.deletedItems.count, 1)
        XCTAssertEqual(result.failedItems.count, 1)
        XCTAssertEqual(result.failedItems[0].error, "Access denied")
    }
    
    func testAppInfo() {
        let app = AppInfo(
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            path: URL(fileURLWithPath: "/Applications/TestApp.app"),
            version: "1.0.0",
            size: 1024000
        )
        
        XCTAssertEqual(app.name, "TestApp")
        XCTAssertEqual(app.bundleIdentifier, "com.test.app")
        XCTAssertEqual(app.version, "1.0.0")
        XCTAssertEqual(app.size, 1024000)
        XCTAssertEqual(app.id, "com.test.app")
    }
    
    func testLargeFile() {
        let file = LargeFile(
            path: URL(fileURLWithPath: "/tmp/large.zip"),
            size: 500_000_000,
            modifiedDate: Date(),
            fileType: "public.zip-archive"
        )
        
        XCTAssertEqual(file.size, 500_000_000)
        XCTAssertEqual(file.fileType, "public.zip-archive")
        XCTAssertNotNil(file.modifiedDate)
    }
    
    func testCleanupLog() {
        let log = CleanupLog(
            operation: "Cache Cleanup",
            itemsDeleted: 10,
            freedSpace: 1024000,
            details: ["/tmp/a", "/tmp/b"]
        )
        
        XCTAssertEqual(log.operation, "Cache Cleanup")
        XCTAssertEqual(log.itemsDeleted, 10)
        XCTAssertEqual(log.freedSpace, 1024000)
        XCTAssertEqual(log.details.count, 2)
    }
    
    func testCleanupLogCoding() throws {
        let log = CleanupLog(
            operation: "Test Operation",
            itemsDeleted: 5,
            freedSpace: 2048,
            details: []
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CleanupLog.self, from: data)
        
        XCTAssertEqual(decoded.operation, log.operation)
        XCTAssertEqual(decoded.itemsDeleted, log.itemsDeleted)
        XCTAssertEqual(decoded.freedSpace, log.freedSpace)
    }
    
    func testFitMacLogDirectory() {
        XCTAssertTrue(fitMacLogDirectory.path.contains("Library/Logs/FitMac"))
    }
    
    func testFileUtilsIsDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
        XCTAssertTrue(try FileUtils.isDirectory(at: tempDir))
        
        let tempFile = tempDir.appendingPathComponent("test_file_\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        XCTAssertFalse(try FileUtils.isDirectory(at: tempFile))
    }
    
    func testFileUtilsMoveToTrash() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_trash_\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tempFile.path, contents: "test".data(using: .utf8))
        
        let trashURL = try FileUtils.moveToTrash(at: tempFile)
        XCTAssertNotNil(trashURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))
    }
    
    func testPermissionUtilsHasFullDiskAccess() {
        let _ = PermissionUtils.hasFullDiskAccess()
    }
    
    func testFitMacErrorPermissionDenied() {
        let error = FitMacError.permissionDenied(path: "/test/path")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Permission denied") ?? false)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testFitMacErrorScanFailed() {
        let error = FitMacError.scanFailed(reason: "Test reason")
        XCTAssertEqual(error.errorDescription, "Scan failed: Test reason")
    }
    
    func testFitMacErrorScanFailedWithUnderlying() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "underlying error"])
        let error = FitMacError.scanFailed(reason: "Test", underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("underlying error") ?? false)
    }
    
    func testFitMacErrorHomebrewNotInstalled() {
        let error = FitMacError.homebrewNotInstalled
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testFitMacErrorAppRunning() {
        let error = FitMacError.appRunning(appName: "TestApp")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TestApp") ?? false)
    }
    
    func testFitMacErrorSystemItemProtected() {
        let error = FitMacError.systemItemProtected(item: "SystemApp")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.isRecoverable)
    }
    
    func testFitMacErrorCleanupPartial() {
        let error = FitMacError.cleanupPartial(freedSpace: 1024, failedCount: 2, errors: ["Error1", "Error2"])
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Partial cleanup") || error.errorDescription!.contains("1 KB") || error.errorDescription!.contains("1024"))
    }
    
    func testScanErrorDirectoryNotReadable() {
        let error = ScanError.directoryNotReadable(path: "/test", reason: "No access")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("No access") ?? false)
    }
    
    func testScanErrorNoItemsFound() {
        let error = ScanError.noItemsFound
        XCTAssertEqual(error.errorDescription, "No items found")
    }
    
    func testCleanErrorMoveToTrashFailed() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test"])
        let error = CleanError.moveToTrashFailed(path: "/test/file", underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("trash") ?? false)
    }
    
    func testErrorIsCancellation() {
        let fitMacCancelled = FitMacError.operationCancelled
        XCTAssertTrue(fitMacCancelled.isCancellation)
        
        let scanCancelled = ScanError.cancelled
        XCTAssertTrue(scanCancelled.isCancellation)
        
        let otherError = FitMacError.permissionDenied(path: "/test")
        XCTAssertFalse(otherError.isCancellation)
    }
    
    func testErrorContextEnrichedError() {
        let context = ErrorContext(operation: "TestOp", path: URL(fileURLWithPath: "/test"), additionalInfo: ["key": "value"])
        let original = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "original error"])
        let enriched = context.enrichedError(original)
        
        XCTAssertNotNil((enriched as? LocalizedError)?.errorDescription)
        XCTAssertTrue((enriched as? LocalizedError)?.errorDescription?.contains("TestOp") ?? false)
    }
    
    func testDuplicateFile() {
        let file = DuplicateFile(
            path: URL(fileURLWithPath: "/test/file.pdf"),
            size: 1024,
            hash: "abc123",
            modifiedDate: Date(),
            fileType: "pdf"
        )
        
        XCTAssertEqual(file.size, 1024)
        XCTAssertEqual(file.hash, "abc123")
        XCTAssertEqual(file.fileType, "pdf")
    }
    
    func testDuplicateGroup() {
        let files = [
            DuplicateFile(path: URL(fileURLWithPath: "/a"), size: 100, hash: "h1", modifiedDate: nil, fileType: "txt"),
            DuplicateFile(path: URL(fileURLWithPath: "/b"), size: 100, hash: "h1", modifiedDate: nil, fileType: "txt"),
            DuplicateFile(path: URL(fileURLWithPath: "/c"), size: 100, hash: "h1", modifiedDate: nil, fileType: "txt")
        ]
        
        let group = DuplicateGroup(files: files, hash: "h1")
        
        XCTAssertEqual(group.files.count, 3)
        XCTAssertEqual(group.fileSize, 100)
        XCTAssertEqual(group.wastage, 200)
        XCTAssertEqual(group.totalSize, 300)
    }
    
    func testDuplicateGroupSingleFile() {
        let files = [
            DuplicateFile(path: URL(fileURLWithPath: "/a"), size: 100, hash: "h1", modifiedDate: nil, fileType: "txt")
        ]
        
        let group = DuplicateGroup(files: files, hash: "h1")
        
        XCTAssertEqual(group.wastage, 0)
        XCTAssertEqual(group.totalSize, 100)
    }
}
