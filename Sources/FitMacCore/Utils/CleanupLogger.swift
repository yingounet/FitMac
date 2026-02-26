import Foundation

public struct CleanupLog: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let operation: String
    public let itemsDeleted: Int
    public let freedSpace: Int64
    public let details: [String]
    
    public init(operation: String, itemsDeleted: Int, freedSpace: Int64, details: [String] = []) {
        self.id = UUID()
        self.date = Date()
        self.operation = operation
        self.itemsDeleted = itemsDeleted
        self.freedSpace = freedSpace
        self.details = details
    }
}

public actor CleanupLogger {
    public static let shared = CleanupLogger()
    
    private let logDirectory: URL
    private let currentLogFile: URL
    
    private init() {
        logDirectory = fitMacLogDirectory
        currentLogFile = logDirectory.appendingPathComponent("cleanup.log")
    }
    
    public func log(_ entry: CleanupLog) throws {
        try ensureLogDirectory()
        
        var logs = try loadLogs()
        logs.append(entry)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(logs)
        try data.write(to: currentLogFile)
    }
    
    public func loadLogs() throws -> [CleanupLog] {
        guard FileManager.default.fileExists(atPath: currentLogFile.path) else {
            return []
        }
        
        let data = try Data(contentsOf: currentLogFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([CleanupLog].self, from: data)
    }
    
    public func clearLogs() throws {
        if FileManager.default.fileExists(atPath: currentLogFile.path) {
            try FileManager.default.removeItem(at: currentLogFile)
        }
    }
}
