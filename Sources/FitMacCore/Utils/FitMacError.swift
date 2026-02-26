import Foundation

public enum FitMacError: Error, LocalizedError {
    case permissionDenied(path: String)
    case fileNotFound(path: String)
    case scanFailed(reason: String)
    case deleteFailed(path: String, underlying: Error)
    case invalidPath(path: String)
    case operationCancelled
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission denied: \(PathUtils.shorten(path))"
        case .fileNotFound(let path):
            return "File not found: \(PathUtils.shorten(path))"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .deleteFailed(let path, let underlying):
            return "Failed to delete \(PathUtils.shorten(path)): \(underlying.localizedDescription)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .operationCancelled:
            return "Operation cancelled"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Grant Full Disk Access in System Settings > Privacy & Security"
        case .fileNotFound:
            return "The file may have been moved or deleted"
        case .scanFailed:
            return "Try selecting a different location or check permissions"
        case .deleteFailed:
            return "The file may be in use or you may not have permission to delete it"
        case .invalidPath:
            return "Please select a valid path"
        case .operationCancelled:
            return nil
        }
    }
}
