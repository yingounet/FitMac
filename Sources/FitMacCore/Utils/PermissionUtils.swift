import Foundation

public enum PermissionUtils {
    public static func hasFullDiskAccess() -> Bool {
        let url = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC")
        return FileManager.default.isReadableFile(atPath: url.path)
    }
}
