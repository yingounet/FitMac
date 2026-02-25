import XCTest
@testable import FitMacCore

final class FitMacCoreTests: XCTestCase {
    
    func testSizeFormatter() {
        XCTAssertTrue(SizeFormatter.format(Int64(0)).contains("0"))
        XCTAssertTrue(SizeFormatter.format(Int64(1024)).contains("1"))
        XCTAssertTrue(SizeFormatter.format(Int64(1048576)).contains("1"))
        XCTAssertTrue(SizeFormatter.format(Int64(1073741824)).contains("1"))
    }
    
    func testCacheCategory() {
        XCTAssertEqual(CacheCategory.systemCache.displayName, "System Cache")
        XCTAssertEqual(CacheCategory.appCache.displayName, "Application Cache")
        XCTAssertEqual(CacheCategory.browserCache.displayName, "Browser Cache")
        XCTAssertEqual(CacheCategory.devCache.displayName, "Developer Cache")
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
    
    func testCachePathsExpansion() {
        let expandedPath = CachePaths.expandedPath("~/Library/Caches")
        XCTAssertTrue(expandedPath.path.contains("Library/Caches"))
        XCTAssertFalse(expandedPath.path.hasPrefix("~"))
    }
    
    func testAppLeftoverPaths() {
        let paths = AppLeftoverPaths.searchPaths(for: "com.example.app")
        XCTAssertFalse(paths.isEmpty)
        
        let hasPreferencesPath = paths.contains { $0.path.contains("Preferences") }
        XCTAssertTrue(hasPreferencesPath)
    }
}
