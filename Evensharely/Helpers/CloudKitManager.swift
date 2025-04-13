//
//  CloudKitManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//

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


    // Save user profile
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
            record["fullName"] = profile.fullName
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
    func fetchAllSharedLinks(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result { return record }
                    return nil
                }
                DispatchQueue.main.async {
                    completion(.success(records))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
   //Fetch the iCloudID and Cache it to keep things speedy
    func fetchAndCacheIcloudID(completion: @escaping (String?) -> Void) {
        if let cached = UserDefaults.standard.string(forKey: "evensharely_icloudID") {
            completion(cached)
            return
        }

        CloudKitConfig.container.fetchUserRecordID{ recordID, error in
            guard let recordID = recordID else {
                print("❌ Could not fetch iCloud ID: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            let id = recordID.recordName
            UserDefaults.standard.set(id, forKey: "evensharely_icloudID")
            completion(id)
        }
    }

    
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
    func fetchUserProfiles(forIcloudIDs ids: [String], completion: @escaping (Result<[UserProfile], Error>) -> Void) {
        guard !ids.isEmpty else {
            completion(.success([]))
            return
        }

        let predicate = NSPredicate(format: "icloudID IN %@", ids)
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


    
    
    
    
    func fetchCurrentUserIcloudID(completion: @escaping (Result<String, Error>) -> Void) {
        container.fetchUserRecordID { recordID, error in
            if let error = error {
                completion(.failure(error))
            } else if let recordID = recordID {
                completion(.success(recordID.recordName))
            }
        }
    }
    
    


    // Fetch shared links for current user
    func fetchSharedLinks(completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        guard let currentUserIcloudID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            print("❌ No iCloud ID found in UserDefaults")
            completion(.success([])) // or return an error instead
            return
        }

        let predicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", currentUserIcloudID)
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
        guard let currentUserIcloudID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            completion(.success([]))
            return
        }

        let datePredicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        let recipientPredicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", currentUserIcloudID)
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



    // Save a shared link
    func saveSharedLink(_ link: SharedLink, completion: @escaping (Result<Void, Error>) -> Void) {
        let record = link.toRecord()
        print("📤 Attempting to save SharedLink to CloudKit: \(link.url)")

        publicDB.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ CloudKit save error: \(error)")
                    completion(.failure(error))
                } else if let saved = savedRecord {
                    print("✅ SharedLink saved to CloudKit. ID: \(saved.recordID.recordName)")
                    completion(.success(()))
                } else {
                    print("⚠️ No error and no saved record — something's off")
                    completion(.failure(NSError(domain: "CloudKitSave", code: -1, userInfo: nil)))
                }
            }
        }
    }

    func fetchAllUserProfiles(completion: @escaping (Result<[UserProfile], Error>) -> Void) {
        let predicate = NSPredicate(value: true) // all users
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        print("I'm inside fetchAllUsers")

        publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 50) { result in
            switch result {
            case .success(let (matchedResults, _)):
                let records = matchedResults.compactMap { _, result in
                    if case let .success(record) = result {
                        return record
                    }
                    return nil
                }
                let profiles = records.compactMap { UserProfile(record: $0) }
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

 
    
    
    
    
}

