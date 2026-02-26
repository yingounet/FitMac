import Foundation

public enum PathUtils {
    public static func shorten(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
    
    public static func shorten(_ url: URL) -> String {
        shorten(url.path)
    }
    
    public static func parseSize(_ string: String) -> Int64 {
        let str = string.uppercased().replacingOccurrences(of: " ", with: "")
        
        if str.hasSuffix("GB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1_073_741_824)
        } else if str.hasSuffix("MB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1_048_576)
        } else if str.hasSuffix("KB") {
            let value = Double(str.dropLast(2)) ?? 0
            return Int64(value * 1024)
        } else {
            return Int64(str) ?? 0
        }
    }
}
