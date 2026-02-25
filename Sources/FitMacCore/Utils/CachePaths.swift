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
            ("~/Library/Safari", .browserCache),
            ("~/Library/Caches/Google/Chrome", .browserCache),
            ("~/Library/Application Support/Google/Chrome/Default/Cache", .browserCache),
            ("~/Library/Caches/Microsoft Edge", .browserCache),
            ("~/Library/Application Support/Microsoft Edge/Default/Cache", .browserCache),
            ("~/Library/Caches/Firefox", .browserCache),
            ("~/Library/Application Support/Firefox/Profiles", .browserCache),
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
    
    public static func expandedPath(_ path: String) -> URL {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
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
