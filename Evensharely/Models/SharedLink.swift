import CloudKit
import Foundation

struct SharedLink: Identifiable {
    var id: CKRecord.ID
    var url: URL
    var reactions: [Reaction] = [] // You can group these for UI
    var senderIcloudID: String
    var senderFullName: String
    var recipientIcloudIDs: [String]
    var tags: [String]
    var date: Date
    var author: String?

    init(
        id: CKRecord.ID,
        url: URL,
        senderIcloudID: String,
        senderFullName: String,
        recipientIcloudIDs: [String],
        tags: [String],
        date: Date,
        author: String? = nil
    ) {
        self.id = id
        self.url = url
        self.senderIcloudID = senderIcloudID
        self.senderFullName = senderFullName
        self.recipientIcloudIDs = recipientIcloudIDs
        self.tags = tags
        self.date = date
        self.author = author
    }

    init(record: CKRecord) {
        self.id = record.recordID
        self.url = URL(string: record["url"] as? String ?? "") ?? URL(string: "https://example.com")!
        self.senderIcloudID = record["senderIcloudID"] as? String ?? ""
        self.senderFullName = record["senderFullName"] as? String ?? "Unknown"
        self.recipientIcloudIDs = record["recipientIcloudIDs"] as? [String] ?? []
        self.tags = record["tags"] as? [String] ?? []
        self.date = record["date"] as? Date ?? Date()
        self.author = record["author"] as? String
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "SharedLink", recordID: id)
        record["url"] = url.absoluteString
        record["senderIcloudID"] = senderIcloudID
        record["senderFullName"] = senderFullName
        record["recipientIcloudIDs"] = recipientIcloudIDs
        record["tags"] = tags
        record["date"] = date
        if let author {                    
            record["author"] = author
        }
        return record
    }

    
}

struct Reaction: Identifiable {
    var id: CKRecord.ID
    var linkID: CKRecord.ID
    var userID: String
    var reactionType: String
    var timestamp: Date
}
