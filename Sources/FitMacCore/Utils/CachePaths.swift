import Foundation

public enum CachePaths {
    public static let userLibrary = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    public static let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    public static let systemLibrary = URL(fileURLWithPath: "/Library")
    
    public static var systemCachePaths: [(path: String, category: CacheCategory)] {
        [
            ("~/Library/Caches", .systemCache),
            ("~/Library/Logs", .logs),
            ("/Library/Caches", .systemCache),
            ("/Library/Logs", .logs),
        ]
    }
    
    public static var appCachePaths: [(path: String, category: CacheCategory)] {
        [
            ("~/Library/Application Support", .appCache),
            ("~/Library/Containers", .appCache),
            ("~/Library/Saved Application State", .appCache),
        ]
    }
    
    public static var browserCachePaths: [(path: String, category: CacheCategory)] {
        [
            ("~/Library/Caches/com.apple.Safari", .browserCache),
            ("~/Library/Safari/LocalStorage", .browserCache),
            ("~/Library/Safari/Databases", .browserCache),
            ("~/Library/Caches/Google/Chrome", .browserCache),
            ("~/Library/Application Support/Google/Chrome/Default/Cache", .browserCache),
            ("~/Library/Application Support/Google/Chrome/Default/Code Cache", .browserCache),
            ("~/Library/Application Support/Google/Chrome/Default/GPUCache", .browserCache),
            ("~/Library/Caches/Microsoft Edge", .browserCache),
            ("~/Library/Application Support/Microsoft Edge/Default/Cache", .browserCache),
            ("~/Library/Application Support/Microsoft Edge/Default/Code Cache", .browserCache),
            ("~/Library/Caches/Firefox", .browserCache),
            ("~/Library/Application Support/Firefox/Profiles/*/cache2", .browserCache),
            ("~/Library/Caches/org.mozilla.firefox", .browserCache),
        ]
    }
    
    public static var devCachePaths: [(path: String, category: CacheCategory)] {
        [
            ("~/Library/Developer/Xcode/DerivedData", .devCache),
            ("~/Library/Developer/Xcode/Archives", .devCache),
            ("~/Library/Developer/Xcode/iOS DeviceSupport", .devCache),
            ("~/.cocoapods", .devCache),
            ("~/.npm", .devCache),
            ("~/.yarn/cache", .devCache),
            ("~/Library/Caches/Homebrew", .devCache),
            ("~/.cache/pip", .devCache),
            ("~/.gradle/caches", .devCache),
            ("~/.m2/repository", .devCache),
        ]
    }
    
    public static var allCachePaths: [(path: String, category: CacheCategory)] {
        systemCachePaths + appCachePaths + browserCachePaths + devCachePaths
    }
    
    public static let browserProtectedPatterns: [String] = [
        "Bookmarks",
        "Bookmarks.bak",
        "Login Data",
        "Login Data-journal",
        "Web Data",
        "Web Data-journal",
        "Cookies",
        "Cookies-journal",
        "Extensions",
        "Extension Rules",
        "Extension State",
        "Extension Scripts",
        "Preferences",
        "Secure Preferences",
        "History",
        "History-journal",
        "Favicons",
        "Favicons-journal",
        "Top Sites",
        "Visited Links",
        "places.sqlite",
        "places.sqlite-wal",
        "places.sqlite-shm",
        "logins.json",
        "key4.db",
        "key3.db",
        "cert9.db",
        "permissions.sqlite",
        "formhistory.sqlite",
        "storage/default/*/idb",
        "*.sqlite",
        "*.db",
        "user.js",
        "prefs.js",
    ]
    
    public static let browserProtectedDirectories: [String] = [
        "Extensions",
        "Extension State",
        "Extension Rules",
        "Extension Scripts",
        "Storage",
        "databases",
        "IndexedDB",
        "File System",
        "Session Storage",
        "Local Extension Settings",
    ]
    
    public static func isProtectedBrowserFile(_ path: String) -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        
        for pattern in browserProtectedPatterns {
            if pattern.hasSuffix("*") {
                let prefix = String(pattern.dropLast())
                if filename.hasPrefix(prefix) { return true }
            } else if filename == pattern {
                return true
            }
        }
        
        let pathLower = path.lowercased()
        let protectedKeywords = [
            "/extensions/",
            "/extension state/",
            "/extension rules/",
            "/storage/default/",
            "/indexeddb/",
            "places.sqlite",
            "logins.json",
            "key4.db",
            "key3.db",
        ]
        
        for keyword in protectedKeywords {
            if pathLower.contains(keyword) { return true }
        }
        
        return false
    }
    
    public static func expandedPath(_ path: String) -> URL {
        if path.contains("*") {
            let expanded = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    
    public static func expandWildcardPath(_ path: String) -> [URL] {
        guard path.contains("*") else {
            let url = expandedPath(path)
            return FileManager.default.fileExists(atPath: url.path) ? [url] : []
        }
        
        let expanded = NSString(string: path).expandingTildeInPath
        let parts = expanded.components(separatedBy: "*")
        
        guard parts.count >= 2 else { return [] }
        
        let basePath = parts[0]
        let suffix = parts.count > 1 ? parts[1] : ""
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var results: [URL] = []
        
        for case let url as URL in enumerator {
            let fullPath = url.path
            if fullPath.hasSuffix(suffix) || (suffix.isEmpty && fullPath.hasPrefix(basePath)) {
                results.append(url)
            }
        }
        
        return results
    }
}

public enum AppLeftoverPaths {
    public static let userLibrary = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    
    public static let searchPatterns: [String] = [
        "~/Library/Preferences/%@",
        "~/Library/Preferences/%@.plist",
        "~/Library/Application Support/%@",
        "~/Library/Caches/%@",
        "~/Library/Containers/%@",
        "~/Library/Logs/%@",
        "~/Library/Saved Application State/%@",
        "~/Library/WebKit/%@",
        "~/Library/Cookies/%@",
        "~/Library/HTTPStorages/%@",
        "~/Library/Group Containers/%@",
    ]
    
    public static func searchPaths(for appIdentifier: String) -> [URL] {
        let bundleIdPattern = appIdentifier.replacingOccurrences(of: ".", with: "\\.")
        let shortName = appIdentifier.components(separatedBy: ".").last ?? appIdentifier
        
        var paths: [URL] = []
        for pattern in searchPatterns {
            let expanded = NSString(string: pattern).expandingTildeInPath
            
            let withBundleId = String(format: expanded, bundleIdPattern)
            paths.append(URL(fileURLWithPath: withBundleId))
            
            let withShortName = String(format: expanded, shortName)
            if withShortName != withBundleId {
                paths.append(URL(fileURLWithPath: withShortName))
            }
        }
        return paths
    }
}
