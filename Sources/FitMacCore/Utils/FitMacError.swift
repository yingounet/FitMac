import Foundation

public enum FitMacError: Error, LocalizedError {
    case permissionDenied(path: String)
    case fileNotFound(path: String)
    case scanFailed(reason: String, underlying: Error? = nil)
    case deleteFailed(path: String, underlying: Error)
    case invalidPath(path: String)
    case operationCancelled
    case homebrewNotInstalled
    case appRunning(appName: String)
    case systemItemProtected(item: String)
    case hashFailed(path: String, underlying: Error)
    case unreadableDirectory(path: String, reason: String? = nil)
    case cleanupPartial(freedSpace: Int64, failedCount: Int, errors: [String])
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission denied: \(PathUtils.shorten(path))"
        case .fileNotFound(let path):
            return "File not found: \(PathUtils.shorten(path))"
        case .scanFailed(let reason, let underlying):
            let base = "Scan failed: \(reason)"
            if let error = underlying {
                return "\(base) - \(error.localizedDescription)"
            }
            return base
        case .deleteFailed(let path, let underlying):
            return "Failed to delete \(PathUtils.shorten(path)): \(underlying.localizedDescription)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .operationCancelled:
            return "Operation cancelled"
        case .homebrewNotInstalled:
            return "Homebrew is not installed"
        case .appRunning(let appName):
            return "Cannot remove '\(appName)': application is currently running"
        case .systemItemProtected(let item):
            return "Cannot modify system item: \(item)"
        case .hashFailed(let path, let underlying):
            return "Failed to compute hash for \(PathUtils.shorten(path)): \(underlying.localizedDescription)"
        case .unreadableDirectory(let path, let reason):
            let base = "Cannot read directory: \(PathUtils.shorten(path))"
            if let reason = reason {
                return "\(base) - \(reason)"
            }
            return base
        case .cleanupPartial(let freedSpace, let failedCount, let errors):
            return "Partial cleanup: freed \(SizeFormatter.format(freedSpace)), \(failedCount) items failed. Errors: \(errors.joined(separator: "; "))"
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
        case .homebrewNotInstalled:
            return "Install Homebrew from https://brew.sh"
        case .appRunning:
            return "Quit the application before removing it"
        case .systemItemProtected:
            return "This item is protected by the system and cannot be modified"
        case .hashFailed:
            return "The file may be corrupted or inaccessible"
        case .unreadableDirectory:
            return "Check if the directory exists and you have read permissions"
        case .cleanupPartial:
            return "Some items could not be cleaned. Check the error details and try again."
        }
    }
    
    public var isRecoverable: Bool {
        switch self {
        case .operationCancelled, .systemItemProtected:
            return false
        default:
            return true
        }
    }
}

public enum ScanError: Error, LocalizedError {
    case directoryNotReadable(path: String, reason: String? = nil)
    case resourceAccessFailed(path: String, resource: String)
    case enumerationFailed(path: String, underlying: Error)
    case noItemsFound
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .directoryNotReadable(let path, let reason):
            let base = "Cannot read directory: \(PathUtils.shorten(path))"
            return reason.map { "\(base) - \($0)" } ?? base
        case .resourceAccessFailed(let path, let resource):
            return "Cannot access \(resource) for: \(PathUtils.shorten(path))"
        case .enumerationFailed(let path, let underlying):
            return "Failed to enumerate \(PathUtils.shorten(path)): \(underlying.localizedDescription)"
        case .noItemsFound:
            return "No items found"
        case .cancelled:
            return "Scan cancelled"
        }
    }
}

public enum CleanError: Error, LocalizedError {
    case itemInUse(path: String)
    case permissionDenied(path: String)
    case itemNotFound(path: String)
    case moveToTrashFailed(path: String, underlying: Error)
    case removeFromTrashFailed(path: String, underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .itemInUse(let path):
            return "Item is in use: \(PathUtils.shorten(path))"
        case .permissionDenied(let path):
            return "Permission denied: \(PathUtils.shorten(path))"
        case .itemNotFound(let path):
            return "Item not found: \(PathUtils.shorten(path))"
        case .moveToTrashFailed(let path, let underlying):
            return "Failed to move to trash: \(PathUtils.shorten(path)) - \(underlying.localizedDescription)"
        case .removeFromTrashFailed(let path, let underlying):
            return "Failed to remove from trash: \(PathUtils.shorten(path)) - \(underlying.localizedDescription)"
        }
    }
}

public struct ErrorContext {
    public let operation: String
    public let path: URL?
    public let additionalInfo: [String: String]
    
    public init(operation: String, path: URL? = nil, additionalInfo: [String: String] = [:]) {
        self.operation = operation
        self.path = path
        self.additionalInfo = additionalInfo
    }
    
    public func enrichedError(_ error: Error) -> Error {
        EnrichedError(original: error, context: self)
    }
}

public struct EnrichedError: Error, LocalizedError {
    public let original: Error
    public let context: ErrorContext
    
    public var errorDescription: String? {
        let baseError = (original as? LocalizedError)?.errorDescription ?? original.localizedDescription
        var details = "[\(context.operation)]"
        if let path = context.path {
            details += " Path: \(PathUtils.shorten(path))"
        }
        for (key, value) in context.additionalInfo {
            details += " \(key): \(value)"
        }
        return "\(details) - \(baseError)"
    }
}

public extension Error {
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let fitMacError = self as? FitMacError, case .operationCancelled = fitMacError { return true }
        if let scanError = self as? ScanError, case .cancelled = scanError { return true }
        return false
    }
    
    var localizedDescriptionWithoutPath: String {
        if let fitMacError = self as? FitMacError {
            switch fitMacError {
            case .permissionDenied, .fileNotFound, .deleteFailed, .invalidPath, .hashFailed, .unreadableDirectory:
                return (self as? LocalizedError)?.errorDescription ?? localizedDescription
            default:
                return (self as? LocalizedError)?.errorDescription ?? localizedDescription
            }
        }
        return (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
