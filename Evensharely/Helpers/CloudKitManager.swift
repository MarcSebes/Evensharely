//
//  CloudKitManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//
import CloudKit
import PhotosUI
import UIKit

class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}
    private let container = CloudKitConfig.container
    
    public var publicDB: CKDatabase {
        container.publicCloudDatabase
    }
    
    public var privateDB: CKDatabase {
        container.privateCloudDatabase
    }
    
    // MARK: - USERPROFILE
    
    func saveOrUpdateUserProfile(appleUserID: String, nameComponents: PersonNameComponents?, email: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        // Existing implementation
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query     = CKQuery(recordType: "UserProfile", predicate: predicate)

        publicDB.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: nil,
            resultsLimit: 1
        ) { fetchResult in
            switch fetchResult {
            case .success(let response):
                let records = response.matchResults.compactMap { _, recResult in
                    if case let .success(record) = recResult { return record }
                    return nil
                }
                
                let recordToSave = records.first ?? CKRecord(recordType: "UserProfile")
                
                recordToSave["appleUserID"] = appleUserID as CKRecordValue
                
                if let comps = nameComponents {
                    let formatter = PersonNameComponentsFormatter()
                    let fullName = formatter.string(from: comps)
                    if fullName != "" {
                        recordToSave["fullName"] = fullName as CKRecordValue
                    } else {
                       NSLog("[CKM] fullName will not be updated because nothing was returned.")
                    }
                }
                
                if let email = email {
                    recordToSave["email"] = email as CKRecordValue
                }
                
                let operation = CKModifyRecordsOperation(
                    recordsToSave: [recordToSave],
                    recordIDsToDelete: nil
                )
                operation.savePolicy = .changedKeys
                operation.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
                self.publicDB.add(operation)

            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func saveUserProfile(_ profile: UserProfile, image: UIImage? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        // Existing implementation
        publicDB.fetch(withRecordID: profile.id) { existingRecord, error in
            let record: CKRecord

            if let existingRecord = existingRecord {
                record = existingRecord
            } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                record = CKRecord(recordType: "UserProfile", recordID: profile.id)
            } else if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            } else {
                record = CKRecord(recordType: "UserProfile", recordID: profile.id)
            }

            record["icloudID"] = profile.icloudID
            record["username"] = profile.username
            record["friends"] = profile.friends

            if let image = image,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
                try? imageData.write(to: tempURL)
                record["avatar"] = CKAsset(fileURL: tempURL)
            }

            self.publicDB.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func fetchPrivateUserProfile(forAppleUserID appleUserID: String, completion:@escaping (Result<UserProfile, Error>) -> Void) {
        // Existing implementation
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let record = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }.first
                
                if let record = record {
                    let profile = UserProfile(record: record)
                    DispatchQueue.main.async {
                        completion(.success(profile))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ProfileError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])))
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchUserProfile(forIcloudID icloudID: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        // Existing implementation
        let predicate = NSPredicate(format: "icloudID == %@", icloudID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let record = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }.first
                let profile = record.map { UserProfile(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(profile))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchUserProfiles(forappleUserIDs ids: [String], completion: @escaping (Result<[UserProfile], Error>) -> Void) {
        // Existing implementation
        guard !ids.isEmpty else {
            completion(.success([]))
            return
        }

        let predicate = NSPredicate(format: "appleUserID IN %@", ids)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result { return record }
                    return nil
                }
                let profiles = records.map { UserProfile(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(profiles))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - SHAREDLINK
    
    func saveSharedLink(_ link: SharedLink, completion: @escaping (Result<Void, Error>) -> Void) {
        // Existing implementation
        let record = link.toRecord()
        if AppDebug.isEnabled && AppDebug.cloudKit {
            print("APPLOGGED: 📤 Attempting to save SharedLink to CloudKit: \(link.url)")
        }
        publicDB.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("APPLOGGED: ❌ CloudKit save error: \(error)")
                    completion(.failure(error))
                } else if let saved = savedRecord {
                    if AppDebug.isEnabled && AppDebug.cloudKit {
                        print("APPLOGGED: ✅ SharedLink saved to CloudKit. ID: \(saved.recordID.recordName)")
                    }
                    completion(.success(()))
                } else {
                    print("APPLOGGED: ⚠️ No error and no saved record — something's off")
                    completion(.failure(NSError(domain: "CloudKitSave", code: -1, userInfo: nil)))
                }
            }
        }
    }
    
    func fetchSharedLinks(completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        // Existing implementation
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            print("APPLOGGED: ❌ No iCloud ID found in UserDefaults")
            completion(.success([]))
            return
        }

        let predicate = NSPredicate(
            format: "ANY recipientIcloudIDs == %@",
            appleID
          )
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchSharedLinks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        // Existing implementation
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            completion(.success([]))
            return
        }

        let datePredicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        let recipientPredicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", appleID)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [recipientPredicate, datePredicate])

        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result { return record }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
 
    
    
    
    // MARK: - Fetch Sent Links



        // MARK: - Fetch Sent Links with Date Range
        
        /// Fetch sent links within a specific date range
        func fetchSentLinks(for senderID: String, fromDate: Date, toDate: Date, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
            let senderPredicate = NSPredicate(format: "senderIcloudID == %@", senderID)
            let datePredicate = NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate)
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [senderPredicate, datePredicate])
            
            let sort = NSSortDescriptor(key: "date", ascending: false)
            let query = CKQuery(recordType: "SharedLink", predicate: compoundPredicate)
            query.sortDescriptors = [sort]
            
            publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .success(let (matchedResults, _)):
                    let records = matchedResults.compactMap { _, result in
                        if case let .success(record) = result {
                            return record
                        }
                        return nil
                    }
                    let links = records.map { SharedLink(record: $0) }
                    DispatchQueue.main.async {
                        completion(.success(links))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }

    func fetchSentLinks(for senderID: String, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        let predicate = NSPredicate(format: "senderIcloudID == %@", senderID)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Sent Links with Pagination
    
//    func fetchSentLinks(for senderID: String, fromDate: Date, toDate: Date, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
//        let senderPredicate = NSPredicate(format: "senderIcloudID == %@", senderID)
//        let datePredicate = NSPredicate(format: "date >= %@ AND date <= %@", fromDate as NSDate, toDate as NSDate)
//        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [senderPredicate, datePredicate])
//        
//        let sort = NSSortDescriptor(key: "date", ascending: false)
//        let query = CKQuery(recordType: "SharedLink", predicate: compoundPredicate)
//        query.sortDescriptors = [sort]
//        
//        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
//            switch result {
//            case .success(let (matchedResults, _)):
//                let records = matchedResults.compactMap { _, result in
//                    if case let .success(record) = result { return record }
//                    return nil
//                }
//                let links = records.map { SharedLink(record: $0) }
//                DispatchQueue.main.async {
//                    completion(.success(links))
//                }
//            case .failure(let error):
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
    
    // MARK: - Fetch Unread Links Only
    
    func fetchUnreadSharedLinks(for userID: String, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        // First get all user's links
        fetchSharedLinks { result in
            switch result {
            case .success(let allLinks):
                // Then filter out the read ones client-side
                let readLinkIDs = ReadLinkTracker.getAllReadLinkIDs(for: userID)
                let unreadLinks = allLinks.filter { !readLinkIDs.contains($0.id.recordName) }
                completion(.success(unreadLinks))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Link Management
    
    func deleteSharedLink(_ link: SharedLink, completion: @escaping (Result<Void, Error>) -> Void) {
        // Existing implementation
        publicDB.delete(withRecordID: link.id) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    func updateSharedLinkTags(recordID: CKRecord.ID, tags: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        // Existing implementation
        let record = CKRecord(recordType: "SharedLink", recordID: recordID)
        record["tags"] = tags as CKRecordValue

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        publicDB.add(op)
    }
    
    // MARK: - NEW: Favorites Management
    
    /// Fetch favorite links for a user
    func fetchFavoriteLinks(userIcloudID: String, completion: @escaping ([SharedLink]) -> Void) {
        let predicate = NSPredicate(format: "userIcloudID == %@", userIcloudID)
        let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)

        let privateDB = CKContainer(identifier: "iCloud.com.marcsebes.evensharely").privateCloudDatabase

        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                print("❌ Failed to fetch FavoriteLink records: \(error)")
                completion([])
            case .success(let (matchResults, _)):
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
                
                // Using the modern fetchRecordsResultBlock instead of fetchRecordsCompletionBlock
                let fetchOp = CKFetchRecordsOperation(recordIDs: linkIDs)
                var sharedLinks: [SharedLink] = []
                
                // Set up the per-record handler
                fetchOp.perRecordResultBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        sharedLinks.append(SharedLink(record: record))
                    case .failure(let error):
                        print("⚠️ Failed to fetch SharedLink \(recordID): \(error)")
                    }
                }
                
                // Set up the result handler using the modern API
                fetchOp.fetchRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        completion(sharedLinks)
                    }
                }

                publicDB.add(fetchOp)
            }
        }
    }
    
    /// Add a link to favorites
    func addToFavorites(link: SharedLink, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let privateDB = container.privateCloudDatabase
        let favoriteID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "FavoriteLink", recordID: favoriteID)
        
        record["userIcloudID"] = userID as CKRecordValue
        record["linkReference"] = CKRecord.Reference(recordID: link.id, action: .none)
        
        privateDB.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Remove a link from favorites
    func removeFromFavorites(link: SharedLink, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let privateDB = container.privateCloudDatabase
        let linkReference = CKRecord.Reference(recordID: link.id, action: .none)
        let predicate = NSPredicate(format: "userIcloudID == %@ AND linkReference == %@", userID, linkReference)
        let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)
        
        privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchResults, _)):
                let recordIDs = matchResults.compactMap { recordID, result in
                    if case .success(_) = result { return recordID }
                    return nil
                }
                
                guard let recordID = recordIDs.first else {
                    DispatchQueue.main.async {
                        completion(.success(()))  // Not found is not an error
                    }
                    return
                }
                
                privateDB.delete(withRecordID: recordID) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Reactions Management
    
    /// Create or update a reaction to a link
    func addReaction(to linkID: CKRecord.ID, from userID: String, reactionType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Check if a reaction already exists
        let predicate = NSPredicate(format: "linkID == %@ AND userID == %@", linkID.recordName, userID)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { _, recResult in
                    if case let .success(record) = recResult { return record }
                    return nil
                }
                
                if let existingRecord = records.first {
                    // Update existing reaction
                    existingRecord["reactionType"] = reactionType as CKRecordValue
                    existingRecord["timestamp"] = Date() as CKRecordValue
                    
                    self.publicDB.save(existingRecord) { _, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                completion(.failure(error))
                            } else {
                                completion(.success(()))
                            }
                        }
                    }
                } else {
                    // Create new reaction
                    let reactionID = CKRecord.ID(recordName: UUID().uuidString)
                    let record = CKRecord(recordType: "Reaction", recordID: reactionID)
                    
                    record["linkID"] = linkID.recordName as CKRecordValue
                    record["userID"] = userID as CKRecordValue
                    record["reactionType"] = reactionType as CKRecordValue
                    record["timestamp"] = Date() as CKRecordValue
                    
                    self.publicDB.save(record) { _, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                completion(.failure(error))
                            } else {
                                completion(.success(()))
                            }
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Remove a reaction from a link
    func removeReaction(from linkID: CKRecord.ID, by userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let predicate = NSPredicate(format: "linkID == %@ AND userID == %@", linkID.recordName, userID)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchResults, _)):
                let recordIDs = matchResults.compactMap { recordID, result in
                    if case .success(_) = result { return recordID }
                    return nil
                }
                
                guard let recordID = recordIDs.first else {
                    DispatchQueue.main.async {
                        completion(.success(()))  // Not found is not an error
                    }
                    return
                }
                
                self.publicDB.delete(withRecordID: recordID) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetch reactions for a link
    func fetchReactions(for linkID: CKRecord.ID, completion: @escaping (Result<[Reaction], Error>) -> Void) {
        let predicate = NSPredicate(format: "linkID == %@", linkID.recordName)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            switch result {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { _, recResult in
                    if case let .success(record) = recResult { return record }
                    return nil
                }
                
                let reactions = records.map { record in
                    Reaction(
                        id: record.recordID,
                        linkID: CKRecord.ID(recordName: record["linkID"] as? String ?? ""),
                        userID: record["userID"] as? String ?? "",
                        reactionType: record["reactionType"] as? String ?? "",
                        timestamp: record["timestamp"] as? Date ?? Date()
                    )
                }
                
                DispatchQueue.main.async {
                    completion(.success(reactions))
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

/*
 //Old CloudKitManager

import CloudKit
import PhotosUI

class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}
    private let container = CloudKitConfig.container
    public var publicDB: CKDatabase {
        container.publicCloudDatabase
    }

    //privateDB is not used yet, but declared here for future use
    public var privateDB: CKDatabase {
        container.privateCloudDatabase
    }

    
    //------------ MARK: USERPROFILE ------------------- //
    //--------------------------------------------------//
    
    //MARK: -- UPSERT USER PROFILE--
    /// Saves or updates a UserProfile record in the public database using "appleUserID" as the unique identifier
    func saveOrUpdateUserProfile(appleUserID: String, nameComponents: PersonNameComponents?, email: String?, completion: @escaping (Result<Void, Error>) -> Void) {
            // 1) Query for existing record by appleUserID field
            let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
            let query     = CKQuery(recordType: "UserProfile", predicate: predicate)

            publicDB.fetch(
                withQuery: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: 1
            ) { fetchResult in
            switch fetchResult {
            case .success(let response):
            // 2) Extract the matching CKRecord
                let records = response.matchResults.compactMap { _, recResult in
                    if case let .success(record) = recResult { return record }
                    return nil
                }
            // 3) Use the existing record or Create a new UserProfile record
                let recordToSave = records.first
                    ?? CKRecord(recordType: "UserProfile")

            // 4) Update the fullName and email fields on the UserProfile
                recordToSave["appleUserID"] = appleUserID as CKRecordValue
                /// a. UserProfile.fullName
                if let comps = nameComponents {
                    let formatter = PersonNameComponentsFormatter()
                    let fullName = formatter.string(from: comps)
                    if fullName != "" {
                        recordToSave["fullName"] = fullName as CKRecordValue
                    } else {
                       NSLog("[CKM] fullName will not be updated because nothing was returned.")
                    }
                }
                /// b. UserProfile.email
                if let email = email {
                    recordToSave["email"] = email as CKRecordValue
                }
        

        // 5) Save the UserProfile Record in Cloudkit database
                let operation = CKModifyRecordsOperation(
                    recordsToSave: [recordToSave],
                    recordIDsToDelete: nil
                )
                operation.savePolicy = .changedKeys
                operation.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
                self.publicDB.add(operation)

            case .failure(let error):
                // Propagate fetch error
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
  
    //MARK: NEED TO UPDATE 1 (FriendsEditView and UserProfileEditView)
    // Save user profile
    // This is deprecated - all callers must be updated!!!!!
    func saveUserProfile(_ profile: UserProfile, image: UIImage? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        publicDB.fetch(withRecordID: profile.id) { existingRecord, error in
            let record: CKRecord

            if let existingRecord = existingRecord {
                // ✅ Update existing record
                record = existingRecord
            } else if let ckError = error as? CKError, ckError.code == .unknownItem {
                // ✅ Record doesn't exist yet, create new
                record = CKRecord(recordType: "UserProfile", recordID: profile.id)
            } else if let error = error {
                // ❌ Some other error
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            } else {
                // Fallback safety
                record = CKRecord(recordType: "UserProfile", recordID: profile.id)
            }

            // Write fields
            record["icloudID"] = profile.icloudID
            record["username"] = profile.username
            NSLog("I am not overwriting Full Name")
           // record["fullName"] = profile.fullName
            record["joined"] = profile.joined
            record["friends"] = profile.friends

            // Handle image asset
            if let image = image,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
                try? imageData.write(to: tempURL)
                record["avatar"] = CKAsset(fileURL: tempURL)
            }

            // Save
            self.publicDB.save(record) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
   
   //MARK: FETCH USERPROFILE FROM DATABASE by appleUserID
    func fetchPrivateUserProfile(forAppleUserID appleUserID: String, completion:@escaping (Result<UserProfile, Error>) -> Void) {
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let record = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }.first
                
                // Handle the optional record properly
                if let record = record {
                    let profile = UserProfile(record: record)
                    DispatchQueue.main.async {
                        completion(.success(profile))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ProfileError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])))
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    //MARK: NEED TO UPDATE 1 (FriendsEditView)
    func fetchUserProfile(forIcloudID icloudID: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        let predicate = NSPredicate(format: "icloudID == %@", icloudID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let record = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }.first
                let profile = record.map { UserProfile(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(profile))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
 
    //MARK: IN USE
    //This is the new code
    func fetchUserProfiles(forappleUserIDs ids: [String], completion: @escaping (Result<[UserProfile], Error>) -> Void) {
        guard !ids.isEmpty else {
            completion(.success([]))
            return
        }

        let predicate = NSPredicate(format: "appleUserID IN %@", ids)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result { return record }
                    return nil
                }
                let profiles = records.map { UserProfile(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(profiles))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    
    
    
    //MARK: --------------SHAREDLINK -----------------  //
    //--------------------------------------------------//
    //MARK: IN USE (ShareExtensionView)
    // Save a shared link
    func saveSharedLink(_ link: SharedLink, completion: @escaping (Result<Void, Error>) -> Void) {
        let record = link.toRecord()
        if AppDebug.isEnabled && AppDebug.cloudKit {
            print("APPLOGGED: 📤 Attempting to save SharedLink to CloudKit: \(link.url)")
        }
        publicDB.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("APPLOGGED: ❌ CloudKit save error: \(error)")
                    completion(.failure(error))
                } else if let saved = savedRecord {
                    if AppDebug.isEnabled && AppDebug.cloudKit {
                        print("APPLOGGED: ✅ SharedLink saved to CloudKit. ID: \(saved.recordID.recordName)")
                    }
                    completion(.success(()))
                } else {
                    print("APPLOGGED: ⚠️ No error and no saved record — something's off")
                    completion(.failure(NSError(domain: "CloudKitSave", code: -1, userInfo: nil)))
                }
            }
        }
    }

    //MARK: NEED TO REVIEW USE (Maybe: ContentView)
    // Fetch shared links for current user
    func fetchSharedLinks(completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            print("APPLOGGED: ❌ No iCloud ID found in UserDefaults")
            completion(.success([])) // or return an error instead
            return
        }

        let predicate = NSPredicate(
            format: "ANY recipientIcloudIDs == %@",
            appleID
          )
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    //MARK: IN USE (ContentView)
    func fetchSharedLinks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            completion(.success([]))
            return
        }

        let datePredicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        let recipientPredicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", appleID)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [recipientPredicate, datePredicate])

        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result { return record }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    //MARK: NEED TO UPDATE (SentView)
    func fetchSentLinks(for senderID: String, completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        let predicate = NSPredicate(format: "senderIcloudID == %@", senderID)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }
                let links = records.map { SharedLink(record: $0) }
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }


  
}


//MARK: IN USE (ContentView)
// In CloudKitManager.swift :contentReference[oaicite:2]{index=2}&#8203;:contentReference[oaicite:3]{index=3}
extension CloudKitManager {
    func deleteSharedLink(_ link: SharedLink, completion: @escaping (Result<Void, Error>) -> Void) {
        publicDB.delete(withRecordID: link.id) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

//MARK: IN USE (ContentView)
extension CloudKitManager {
  /// Only updates the `tags` field of an existing SharedLink
  func updateSharedLinkTags(
    recordID: CKRecord.ID,
    tags: [String],
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    // Create a record stub with JUST the changed keys
    let record = CKRecord(recordType: "SharedLink", recordID: recordID)
    record["tags"] = tags as CKRecordValue

    let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    op.savePolicy = .changedKeys
    op.modifyRecordsResultBlock = { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          completion(.success(()))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }

    publicDB.add(op)
  }
}




//MARK: TODO REMOVE USE OF THIS
//Migration of SharedLink to include new AppleID
extension CloudKitManager {
  func migrateSharedLinks(
    from oldID: String,
    to newID: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let db = container.publicCloudDatabase
    let predicate = NSPredicate(format: "ANY recipientIcloudIDs == %@", oldID)
    let query     = CKQuery(recordType: "SharedLink", predicate: predicate)

    db.fetch(
      withQuery: query,
      inZoneWith: nil,
      desiredKeys: ["recipientIcloudIDs", "senderIcloudID"],
      resultsLimit: CKQueryOperation.maximumResults
    ) { (result: Result<
            (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
             queryCursor: CKQueryOperation.Cursor?),
            Error
          >
    ) in
      switch result {
      case .failure(let fetchError):
        DispatchQueue.main.async(flags: [], execute: {
          completion(.failure(fetchError))
        })

      case .success(let (matchResults, _)):
        var records = matchResults.compactMap { _, recRes in
          if case .success(let rec) = recRes { return rec }
          return nil
        }

        guard !records.isEmpty else {
          DispatchQueue.main.async(flags: [], execute: {
            completion(.success(()))
          })
          return
        }

        // Mutate each record in memory
        for rec in records {
          var ids = rec["recipientIcloudIDs"] as? [String] ?? []
          ids = ids.map { $0 == oldID ? newID : $0 }
          if !ids.contains(newID) { ids.append(newID) }
          rec["recipientIcloudIDs"] = ids as CKRecordValue

          if let sender = rec["senderIcloudID"] as? String, sender == oldID {
            rec["senderIcloudID"] = newID as CKRecordValue
          }
        }

        // 1) Try batch save
        let batchOp = CKModifyRecordsOperation(
          recordsToSave: records,
          recordIDsToDelete: nil
        )
        batchOp.savePolicy = .allKeys
        batchOp.modifyRecordsResultBlock = { (result: Result<Void, Error>) in
          DispatchQueue.main.async(flags: [], execute: {
            switch result {
            case .failure(let err):
              print("[Migration] batch modify failed:", err)
              // fallback to individual saves
              self.saveIndividually(records, in: db, completion: completion)
              return

            case .success:
              print("[Migration] batch modify succeeded; verifying first record…")
              // verify the first one:
              let firstID = records[0].recordID
              db.fetch(withRecordID: firstID) { fetched, verifyError in
                DispatchQueue.main.async(flags: [], execute: {
                  let updated = (fetched?["recipientIcloudIDs"] as? [String]) ?? []
                  print("[Migration] verification recipients:", updated)
                  if updated.contains(newID) {
                    completion(.success(()))
                  } else {
                    print("[Migration] batch didn’t persist array, falling back…")
                    self.saveIndividually(records, in: db, completion: completion)
                  }
                })
              }
            }
          })
        }
        db.add(batchOp)
      }
    }
  }

  /// Fallback: saves each record one at a time
  private func saveIndividually(
    _ records: [CKRecord],
    in db: CKDatabase,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let group = DispatchGroup()
    var firstError: Error?

    for rec in records {
      group.enter()
      db.save(rec, completionHandler: { saved, error in
        if let error = error, firstError == nil {
          firstError = error
          print("[Migration][Fallback] save failed for \(rec.recordID.recordName):", error)
        }
        else {
          print("[Migration][Fallback] saved \(rec.recordID.recordName)")
        }
        group.leave()
      })
    }

    group.notify(queue: .main) {
      if let err = firstError {
        completion(.failure(err))
      } else {
        completion(.success(()))
      }
    }
  }
}



//MARK: IN USE (AuthenticationViewModel, UserProfileView, UserProfileEditView)
extension CloudKitManager {

}

//MARK: TODO REMOVE USE OF THIS
extension CloudKitManager {
  func migrateSentLinks(
    from oldID: String,
    to newID: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let db = container.publicCloudDatabase
    // look for all links YOU sent under the oldID
    let predicate = NSPredicate(format: "senderIcloudID == %@", oldID)
    let query     = CKQuery(recordType: "SharedLink", predicate: predicate)

    db.fetch(
      withQuery: query,
      inZoneWith: nil,
      desiredKeys: ["senderIcloudID"],
      resultsLimit: CKQueryOperation.maximumResults
    ) { result in
      switch result {
      case .failure(let fetchError):
        DispatchQueue.main.async(flags: [], execute: {
          completion(.failure(fetchError))
        })

      case .success(let (matchResults, _)):
        // pull out only the successfully‐fetched CKRecords
        var records = matchResults.compactMap { _, recRes in
          if case .success(let rec) = recRes { return rec }
          return nil
        }

        guard !records.isEmpty else {
          DispatchQueue.main.async(flags: [], execute: {
            completion(.success(()))
          })
          return
        }

        // update each record in memory
        for rec in records {
          if let sender = rec["senderIcloudID"] as? String, sender == oldID {
            rec["senderIcloudID"] = newID as CKRecordValue
          }
        }

        // 1) Batch‐write with only the changed key
        let batchOp = CKModifyRecordsOperation(recordsToSave: records,
                                               recordIDsToDelete: nil)
        batchOp.savePolicy = .changedKeys
        batchOp.modifyRecordsResultBlock = { result in
          DispatchQueue.main.async(flags: [], execute: {
            switch result {
            case .failure(let err):
              print("[Migration] batch modify failed:", err)
              completion(.failure(err))

            case .success:
              print("[Migration] batch modify succeeded; verifying first record…")
              let firstID = records[0].recordID
              // 2) Fetch that first record and confirm the field updated
              db.fetch(withRecordID: firstID) { fetched, verifyError in
                DispatchQueue.main.async(flags: [], execute: {
                  if let fetched = fetched,
                     let updatedSender = fetched["senderIcloudID"] as? String {
                    print("[Migration] verification sender:", updatedSender)
                    if updatedSender == newID {
                      completion(.success(()))
                    } else {
                      print("[Migration] batch didn’t stick!")
                      completion(.failure(NSError(
                        domain: "CloudKitMigration",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey:
                          "senderIcloudID didn’t update to \(newID)"]
                      )))
                    }
                  } else {
                    print("[Migration] verification fetch error:", verifyError as Any)
                    completion(.failure(verifyError ?? NSError(
                      domain: "CloudKitMigration",
                      code: -2,
                      userInfo: nil
                    )))
                  }
                })
              }
            }
          })
        }

        db.add(batchOp)
      }
    }
  }
}


*/
