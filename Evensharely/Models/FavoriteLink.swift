//
//  FavoriteLink.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import CloudKit
import Foundation

struct FavoriteLink: Identifiable, Hashable {
    var id: CKRecord.ID
    var userIcloudID: String
    var linkReference: CKRecord.Reference
    var dateFavorited: Date

    init(id: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString),
         userIcloudID: String,
         linkReference: CKRecord.Reference,
         dateFavorited: Date = Date()) {
        self.id = id
        self.userIcloudID = userIcloudID
        self.linkReference = linkReference
        self.dateFavorited = dateFavorited
    }

    init(record: CKRecord) {
        self.id = record.recordID
        self.userIcloudID = record["userIcloudID"] as? String ?? ""
        self.linkReference = record["linkReference"] as? CKRecord.Reference ?? CKRecord.Reference(recordID: CKRecord.ID(recordName: "invalid"), action: .none)
        self.dateFavorited = record["dateFavorited"] as? Date ?? Date()
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "FavoriteLink", recordID: id)
        record["userIcloudID"] = userIcloudID
        record["linkReference"] = linkReference
        record["dateFavorited"] = dateFavorited
        return record
    }
}


func favorite(link: SharedLink, userIcloudID: String) {
    let linkReference = CKRecord.Reference(recordID: link.id, action: .none)
    let favorite = FavoriteLink(userIcloudID: userIcloudID, linkReference: linkReference)
    let record = favorite.toRecord()

    let privateDB = CloudKitConfig.container.privateCloudDatabase
    privateDB.save(record) { savedRecord, error in
        if let error = error {
            print("❌ Error saving FavoriteLink: \(error)")
        } else {
            print("✅ FavoriteLink saved for \(link.url)")
        }
    }
}

func loadFavoritedLinks(userIcloudID: String, completion: @escaping ([SharedLink]) -> Void) {
    let predicate = NSPredicate(format: "userIcloudID == %@", userIcloudID)
    let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)

    let privateDB = CKContainer(identifier: "iCloud.com.marcsebes.evensharely").privateCloudDatabase

    privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { fetchResult in
        switch fetchResult {
        case .failure(let error):
            print("❌ Failed to fetch FavoriteLink records: \(error)")
            completion([])
        case .success(let (matchResults, _)):  // ✅ destructure the tuple
            let linkIDs: [CKRecord.ID] = matchResults.compactMap { (_, result) in
                switch result {
                case .success(let record):
                    return (record["linkReference"] as? CKRecord.Reference)?.recordID
                case .failure(let error):
                    print("⚠️ Error with FavoriteLink record: \(error)")
                    return nil
                }
            }

            guard !linkIDs.isEmpty else {
                completion([])
                return
            }

            let publicDB = CKContainer(identifier: "iCloud.com.marcsebes.evensharely").publicCloudDatabase
            var sharedLinks: [SharedLink] = []

            let fetchOp = CKFetchRecordsOperation(recordIDs: linkIDs)
            fetchOp.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let record):
                    sharedLinks.append(SharedLink(record: record))
                case .failure(let error):
                    print("⚠️ Failed to fetch SharedLink \(recordID): \(error)")
                }
            }

            fetchOp.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    completion(sharedLinks)
                case .failure(let error):
                    print("❌ Fetching SharedLinks failed: \(error)")
                    completion([])
                }
            }

            publicDB.add(fetchOp)
        }
    }
}
