import Foundation

public struct MailAttachment: Identifiable, Codable, Hashable {
    public let id: UUID
    public let filename: String
    public let path: URL
    public let size: Int64
    public let sender: String?
    public let subject: String?
    public let receivedDate: Date?
    public let mailbox: String?
    
    public init(filename: String, path: URL, size: Int64, sender: String? = nil, subject: String? = nil, receivedDate: Date? = nil, mailbox: String? = nil) {
        self.id = UUID()
        self.filename = filename
        self.path = path
        self.size = size
        self.sender = sender
        self.subject = subject
        self.receivedDate = receivedDate
        self.mailbox = mailbox
    }
}

public struct MailScanResult: Codable {
    public let attachments: [MailAttachment]
    public let totalSize: Int64
    public let scanDate: Date
    
    public init(attachments: [MailAttachment], scanDate: Date = Date()) {
        self.attachments = attachments
        self.scanDate = scanDate
        self.totalSize = attachments.reduce(0) { $0 + $1.size }
    }
}

public actor MailScanner {
    private let minAttachmentSize: Int64
    
    public init(minSizeKB: Int64 = 100) {
        self.minAttachmentSize = minSizeKB * 1024
    }
    
    public func scan() async throws -> MailScanResult {
        var attachments: [MailAttachment] = []
        let fileManager = FileManager.default
        
        let mailPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Mail")
        
        guard fileManager.fileExists(atPath: mailPath.path) else {
            return MailScanResult(attachments: [])
        }
        
        guard let versionDirs = try? fileManager.contentsOfDirectory(
            at: mailPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return MailScanResult(attachments: [])
        }
        
        for versionDir in versionDirs {
            let dirName = versionDir.lastPathComponent
            guard dirName.hasPrefix("V") else { continue }
            
            let attachmentsFound = await scanMailVersion(versionDir)
            attachments.append(contentsOf: attachmentsFound)
        }
        
        let sortedAttachments = attachments.sorted { $0.size > $1.size }
        
        return MailScanResult(attachments: sortedAttachments)
    }
    
    private func scanMailVersion(_ versionDir: URL) async -> [MailAttachment] {
        var attachments: [MailAttachment] = []
        let fileManager = FileManager.default
        
        let subdirs = ["INBOX.mbox", "Sent.mbox", "Drafts.mbox", "Archive.mbox"]
        
        for subdir in subdirs {
            let mboxPath = versionDir.appendingPathComponent(subdir)
            let found = await scanMailbox(mboxPath, mailboxName: subdir.replacingOccurrences(of: ".mbox", with: ""))
            attachments.append(contentsOf: found)
        }
        
        if let otherDirs = try? fileManager.contentsOfDirectory(at: versionDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for dir in otherDirs {
                let name = dir.lastPathComponent
                guard name.hasSuffix(".mbox") && !subdirs.contains(name) else { continue }
                let found = await scanMailbox(dir, mailboxName: name.replacingOccurrences(of: ".mbox", with: ""))
                attachments.append(contentsOf: found)
            }
        }
        
        let downloadsPath = versionDir.appendingPathComponent("MailData").appendingPathComponent("Downloads")
        if fileManager.fileExists(atPath: downloadsPath.path) {
            let found = await scanDownloadsFolder(downloadsPath)
            attachments.append(contentsOf: found)
        }
        
        return attachments
    }
    
    private func scanMailbox(_ mboxPath: URL, mailboxName: String) async -> [MailAttachment] {
        var attachments: [MailAttachment] = []
        let fileManager = FileManager.default
        
        let messagesPath = mboxPath.appendingPathComponent("Messages")
        
        guard fileManager.fileExists(atPath: messagesPath.path) else {
            return attachments
        }
        
        guard let enumerator = fileManager.enumerator(
            at: messagesPath,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return attachments
        }
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard !ext.isEmpty && ext != "emlx" && ext != "emlxpart" && ext != "plist" else { continue }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                
                guard resourceValues.isDirectory != true,
                      let fileSize = resourceValues.fileSize,
                      Int64(fileSize) >= minAttachmentSize else {
                    continue
                }
                
                let filename = fileURL.lastPathComponent
                let modifiedDate = resourceValues.contentModificationDate
                
                attachments.append(MailAttachment(
                    filename: filename,
                    path: fileURL,
                    size: Int64(fileSize),
                    sender: nil,
                    subject: nil,
                    receivedDate: modifiedDate,
                    mailbox: mailboxName
                ))
            } catch {
                continue
            }
        }
        
        let attachmentsPath = mboxPath.appendingPathComponent("Attachments")
        if fileManager.fileExists(atPath: attachmentsPath.path) {
            let found = await scanAttachmentsFolder(attachmentsPath, mailboxName: mailboxName)
            attachments.append(contentsOf: found)
        }
        
        return attachments
    }
    
    private func scanAttachmentsFolder(_ attachmentsPath: URL, mailboxName: String) async -> [MailAttachment] {
        var attachments: [MailAttachment] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: attachmentsPath,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return attachments
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                
                guard resourceValues.isDirectory != true,
                      let fileSize = resourceValues.fileSize,
                      Int64(fileSize) >= minAttachmentSize else {
                    continue
                }
                
                let filename = fileURL.lastPathComponent
                let modifiedDate = resourceValues.contentModificationDate
                
                attachments.append(MailAttachment(
                    filename: filename,
                    path: fileURL,
                    size: Int64(fileSize),
                    sender: nil,
                    subject: nil,
                    receivedDate: modifiedDate,
                    mailbox: mailboxName
                ))
            } catch {
                continue
            }
        }
        
        return attachments
    }
    
    private func scanDownloadsFolder(_ downloadsPath: URL) async -> [MailAttachment] {
        var attachments: [MailAttachment] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: downloadsPath,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return attachments
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                
                guard resourceValues.isDirectory != true,
                      let fileSize = resourceValues.fileSize,
                      Int64(fileSize) >= minAttachmentSize else {
                    continue
                }
                
                let filename = fileURL.lastPathComponent
                let modifiedDate = resourceValues.contentModificationDate
                
                attachments.append(MailAttachment(
                    filename: filename,
                    path: fileURL,
                    size: Int64(fileSize),
                    sender: nil,
                    subject: nil,
                    receivedDate: modifiedDate,
                    mailbox: "Downloads"
                ))
            } catch {
                continue
            }
        }
        
        return attachments
    }
}

public actor MailCleaner {
    public init() {}
    
    public func clean(attachments: [MailAttachment], dryRun: Bool = true) async throws -> CleanupResult {
        var deletedItems: [CleanupItem] = []
        var failedItems: [FailedItem] = []
        var freedSpace: Int64 = 0
        
        for attachment in attachments {
            do {
                if dryRun {
                    let cleanupItem = CleanupItem(
                        path: attachment.path,
                        category: .temporary,
                        size: attachment.size,
                        isDirectory: false
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += attachment.size
                } else {
                    _ = try FileUtils.moveToTrash(at: attachment.path)
                    let cleanupItem = CleanupItem(
                        path: attachment.path,
                        category: .temporary,
                        size: attachment.size,
                        isDirectory: false
                    )
                    deletedItems.append(cleanupItem)
                    freedSpace += attachment.size
                }
            } catch {
                let cleanupItem = CleanupItem(
                    path: attachment.path,
                    category: .temporary,
                    size: attachment.size,
                    isDirectory: false
                )
                failedItems.append(FailedItem(item: cleanupItem, error: error.localizedDescription))
            }
        }
        
        return CleanupResult(
            deletedItems: deletedItems,
            failedItems: failedItems,
            freedSpace: freedSpace
        )
    }
}
