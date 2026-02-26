import Foundation
import AppKit
import FitMacCore

enum PermissionHelper {
    static func hasFullDiskAccess() -> Bool {
        PermissionUtils.hasFullDiskAccess()
    }
    
    static func openSystemPreferencesPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
