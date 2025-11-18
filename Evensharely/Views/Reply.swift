import Foundation
import CloudKit

struct Reply: Identifiable, Hashable {
    let id: CKRecord.ID
    let linkID: CKRecord.ID
    let userID: String
    let text: String
    let timestamp: Date
    
    init(id: CKRecord.ID, linkID: CKRecord.ID, userID: String, text: String, timestamp: Date) {
        self.id = id
        self.linkID = linkID
        self.userID = userID
        self.text = text
        self.timestamp = timestamp
    }
    
    init(record: CKRecord) {
        self.id = record.recordID
        let linkIDString = record["linkID"] as? String ?? ""
        self.linkID = CKRecord.ID(recordName: linkIDString)
        self.userID = record["userID"] as? String ?? ""
        self.text = record["text"] as? String ?? ""
        self.timestamp = record["timestamp"] as? Date ?? Date()
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "Reply", recordID: id)
        record["linkID"] = linkID.recordName as CKRecordValue
        record["userID"] = userID as CKRecordValue
        record["text"] = text as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        return record
    }
}
