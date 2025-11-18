//
//  CloudKitManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//  Updated with proper error handling and retry logic
//
import CloudKit
import PhotosUI
import UIKit

class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}
    private let container = CloudKitConfig.container
    private let errorHandler = CloudKitErrorHandler.shared
    
    public var publicDB: CKDatabase {
        container.publicCloudDatabase
    }
    
    public var privateDB: CKDatabase {
        container.privateCloudDatabase
    }
    
    // MARK: - USERPROFILE with Error Handling
    
    func saveOrUpdateUserProfile(
        appleUserID: String,
        nameComponents: PersonNameComponents?,
        email: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                // FIXED: Remove unused 'result' variable
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.saveOrUpdateUserProfileAsync(
                            appleUserID: appleUserID,
                            nameComponents: nameComponents,
                            email: email
                        )
                    },
                    onRetry: { attempt, delay in
                        print("🔄 Retrying saveOrUpdateUserProfile (attempt \(attempt)) after \(delay)s")
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func saveOrUpdateUserProfileAsync(
        appleUserID: String,
        nameComponents: PersonNameComponents?,
        email: String?
    ) async throws {
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        let recordToSave = records.first ?? CKRecord(recordType: "UserProfile")
        
        recordToSave["appleUserID"] = appleUserID as CKRecordValue
        
        if let comps = nameComponents {
            let formatter = PersonNameComponentsFormatter()
            let fullName = formatter.string(from: comps)
            if !fullName.isEmpty {
                recordToSave["fullName"] = fullName as CKRecordValue
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
        operation.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            self.publicDB.add(operation)
        }
    }
    
    func saveUserProfile(
        _ profile: UserProfile,
        image: UIImage? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                // FIXED: Remove unused 'result' variable
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.saveUserProfileAsync(profile, image: image)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func saveUserProfileAsync(_ profile: UserProfile, image: UIImage?) async throws {
        let record: CKRecord
        
        do {
            record = try await publicDB.record(for: profile.id)
        } catch {
            let cloudKitError = errorHandler.classifyError(error)
            if case .notFound = cloudKitError {
                record = CKRecord(recordType: "UserProfile", recordID: profile.id)
            } else {
                throw cloudKitError
            }
        }
        
        record["icloudID"] = profile.icloudID
        record["username"] = profile.username
        record["friends"] = profile.friends
        
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).jpg")
            try imageData.write(to: tempURL)
            record["avatar"] = CKAsset(fileURL: tempURL)
        }
        
        _ = try await publicDB.save(record)
    }
    
    func fetchPrivateUserProfile(
        forAppleUserID appleUserID: String,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        Task {
            do {
                let profile = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchPrivateUserProfileAsync(forAppleUserID: appleUserID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(profile))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchPrivateUserProfileAsync(forAppleUserID appleUserID: String) async throws -> UserProfile {
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        guard let record = matchResults.compactMap({ _, result in try? result.get() }).first else {
            throw CloudKitError.notFound
        }
        
        return UserProfile(record: record)
    }
    
    func fetchUserProfile(
        forIcloudID icloudID: String,
        completion: @escaping (Result<UserProfile?, Error>) -> Void
    ) {
        Task {
            do {
                let profile = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchUserProfileAsync(forIcloudID: icloudID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(profile))
                }
            } catch {
                let cloudKitError = errorHandler.classifyError(error)
                if case .notFound = cloudKitError {
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func fetchUserProfileAsync(forIcloudID icloudID: String) async throws -> UserProfile? {
        let predicate = NSPredicate(format: "icloudID == %@", icloudID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        guard let record = matchResults.compactMap({ _, result in try? result.get() }).first else {
            return nil
        }
        
        return UserProfile(record: record)
    }
    
    func fetchUserProfiles(
        forappleUserIDs ids: [String],
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        guard !ids.isEmpty else {
            completion(.success([]))
            return
        }
        
        Task {
            do {
                let profiles = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchUserProfilesAsync(forappleUserIDs: ids)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(profiles))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchUserProfilesAsync(forappleUserIDs ids: [String]) async throws -> [UserProfile] {
        let predicate = NSPredicate(format: "appleUserID IN %@", ids)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 50)
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        return records.map { UserProfile(record: $0) }
    }
    
    // MARK: - SHAREDLINK with Error Handling
    
    func saveSharedLink(
        _ link: SharedLink,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if AppDebug.isEnabled && AppDebug.cloudKit {
            print("APPLOGGED: 📤 Attempting to save SharedLink to CloudKit: \(link.url)")
        }
        
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.saveSharedLinkAsync(link)
                    },
                    onRetry: { attempt, delay in
                        print("🔄 Retrying saveSharedLink (attempt \(attempt)) after \(delay)s")
                    }
                )
                
                if AppDebug.isEnabled && AppDebug.cloudKit {
                    print("APPLOGGED: ✅ SharedLink saved to CloudKit. ID: \(link.id.recordName)")
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("APPLOGGED: ❌ CloudKit save error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func saveSharedLinkAsync(_ link: SharedLink) async throws {
        let record = link.toRecord()
        _ = try await publicDB.save(record)
    }
    
    func fetchSharedLinks(completion: @escaping (Result<[SharedLink], Error>) -> Void) {
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            print("APPLOGGED: ❌ No iCloud ID found in UserDefaults")
            completion(.success([]))
            return
        }
        
        Task {
            do {
                let links = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchSharedLinksAsync(for: appleID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchSharedLinksAsync(for appleID: String) async throws -> [SharedLink] {
        let predicate = NSPredicate(format: "ANY recipientIcloudIDs == %@", appleID)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]
        
        let (matchResults, _) = try await publicDB.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        return records.map { SharedLink(record: $0) }
    }
    
    func fetchSharedLinks(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[SharedLink], Error>) -> Void
    ) {
        guard let appleID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            completion(.success([]))
            return
        }
        
        Task {
            do {
                let links = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchSharedLinksAsync(
                            for: appleID,
                            from: startDate,
                            to: endDate
                        )
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchSharedLinksAsync(
        for appleID: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SharedLink] {
        let datePredicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        let recipientPredicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", appleID)
        let predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [recipientPredicate, datePredicate]
        )
        
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let (matchResults, _) = try await publicDB.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        return records.map { SharedLink(record: $0) }
    }
    
    // MARK: - Fetch Sent Links with Error Handling
    
    func fetchSentLinks(
        for senderID: String,
        fromDate: Date,
        toDate: Date,
        completion: @escaping (Result<[SharedLink], Error>) -> Void
    ) {
        Task {
            do {
                let links = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchSentLinksAsync(
                            for: senderID,
                            fromDate: fromDate,
                            toDate: toDate
                        )
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchSentLinksAsync(
        for senderID: String,
        fromDate: Date,
        toDate: Date
    ) async throws -> [SharedLink] {
        let senderPredicate = NSPredicate(format: "senderIcloudID == %@", senderID)
        let datePredicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            fromDate as NSDate,
            toDate as NSDate
        )
        let compoundPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [senderPredicate, datePredicate]
        )
        
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: compoundPredicate)
        query.sortDescriptors = [sort]
        
        let (matchResults, _) = try await publicDB.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        return records.map { SharedLink(record: $0) }
    }
    
    func fetchSentLinks(
        for senderID: String,
        completion: @escaping (Result<[SharedLink], Error>) -> Void
    ) {
        Task {
            do {
                let links = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchSentLinksAsync(for: senderID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(links))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchSentLinksAsync(for senderID: String) async throws -> [SharedLink] {
        let predicate = NSPredicate(format: "senderIcloudID == %@", senderID)
        let sort = NSSortDescriptor(key: "date", ascending: false)
        let query = CKQuery(recordType: "SharedLink", predicate: predicate)
        query.sortDescriptors = [sort]
        
        let (matchResults, _) = try await publicDB.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        
        let records = matchResults.compactMap { _, result in
            try? result.get()
        }
        
        return records.map { SharedLink(record: $0) }
    }
    
    // MARK: - Fetch Unread Links Only
    
    func fetchUnreadSharedLinks(
        for userID: String,
        completion: @escaping (Result<[SharedLink], Error>) -> Void
    ) {
        fetchSharedLinks { result in
            switch result {
            case .success(let allLinks):
                let readLinkIDs = ReadLinkTracker.getAllReadLinkIDs(for: userID)
                let unreadLinks = allLinks.filter { !readLinkIDs.contains($0.id.recordName) }
                completion(.success(unreadLinks))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Link Management with Error Handling
    
    func deleteSharedLink(
        _ link: SharedLink,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                // FIXED: Remove 'return' keyword since deleteRecord returns Void
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        try await self.publicDB.deleteRecord(withID: link.id)
                    },
                    maxAttempts: 2 // Fewer retries for delete operations
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateSharedLinkTags(
        recordID: CKRecord.ID,
        tags: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.updateSharedLinkTagsAsync(recordID: recordID, tags: tags)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func updateSharedLinkTagsAsync(recordID: CKRecord.ID, tags: [String]) async throws {
        let record = CKRecord(recordType: "SharedLink", recordID: recordID)
        record["tags"] = tags as CKRecordValue
        
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { continuation in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            publicDB.add(op)
        }
    }
    
    // MARK: - Favorites Management with Error Handling
    
    func fetchFavoriteLinks(
        userIcloudID: String,
        completion: @escaping ([SharedLink]) -> Void
    ) {
        Task {
            do {
                let links = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchFavoriteLinksAsync(userIcloudID: userIcloudID)
                    }
                )
                DispatchQueue.main.async {
                    completion(links)
                }
            } catch {
                print("❌ Failed to fetch favorite links: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    private func fetchFavoriteLinksAsync(userIcloudID: String) async throws -> [SharedLink] {
        let predicate = NSPredicate(format: "userIcloudID == %@", userIcloudID)
        let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)
        
        let (matchResults, _) = try await privateDB.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )
        
        let linkIDs: [CKRecord.ID] = matchResults.compactMap { _, result in
            guard let record = try? result.get(),
                  let linkRef = record["linkReference"] as? CKRecord.Reference else { return nil }
            return linkRef.recordID
        }
        
        guard !linkIDs.isEmpty else { return [] }
        
        // Fetch the actual SharedLink records
        let fetchOp = CKFetchRecordsOperation(recordIDs: linkIDs)
        var sharedLinks: [SharedLink] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            fetchOp.perRecordResultBlock = { _, result in
                if case .success(let record) = result {
                    sharedLinks.append(SharedLink(record: record))
                }
            }
            
            fetchOp.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: sharedLinks)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            publicDB.add(fetchOp)
        }
    }
    
    func addToFavorites(
        link: SharedLink,
        userID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.addToFavoritesAsync(link: link, userID: userID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func addToFavoritesAsync(link: SharedLink, userID: String) async throws {
        let favoriteID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "FavoriteLink", recordID: favoriteID)
        
        record["userIcloudID"] = userID as CKRecordValue
        record["linkReference"] = CKRecord.Reference(recordID: link.id, action: .none)
        
        _ = try await privateDB.save(record)
    }
    
    func removeFromFavorites(
        link: SharedLink,
        userID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.removeFromFavoritesAsync(link: link, userID: userID)
                    },
                    maxAttempts: 2
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func removeFromFavoritesAsync(link: SharedLink, userID: String) async throws {
        let linkReference = CKRecord.Reference(recordID: link.id, action: .none)
        let predicate = NSPredicate(format: "userIcloudID == %@ AND linkReference == %@", userID, linkReference)
        let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)
        
        let (matchResults, _) = try await privateDB.records(matching: query, resultsLimit: 1)
        
        guard let recordID = matchResults.first?.0 else {
            // Not found is not an error for removal
            return
        }
        
        try await publicDB.deleteRecord(withID: recordID)
    }
    
    func fetchReactions(
        for linkID: CKRecord.ID,
        completion: @escaping (Result<[Reaction], Error>) -> Void
    ) {
        Task {
            do {
                let reactions = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchReactionsAsync(for: linkID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(reactions))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func fetchReactionsAsync(for linkID: CKRecord.ID) async throws -> [Reaction] {
        let predicate = NSPredicate(format: "linkID == %@", linkID.recordName)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 100)
        
        let reactions = matchResults.compactMap { _, result -> Reaction? in
            guard let record = try? result.get() else { return nil }
            
            return Reaction(
                id: record.recordID,
                linkID: CKRecord.ID(recordName: record["linkID"] as? String ?? ""),
                userID: record["userID"] as? String ?? "",
                reactionType: record["reactionType"] as? String ?? "",
                timestamp: record["timestamp"] as? Date ?? Date()
            )
        }
        
        return reactions
    }
    
    // MARK: - Batch Operations with Error Handling
    
    /// Batch fetch multiple records with partial failure handling
    func batchFetchRecords(
        recordIDs: [CKRecord.ID],
        database: CKDatabase? = nil,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        guard !recordIDs.isEmpty else {
            completion(.success([]))
            return
        }
        
        let db = database ?? publicDB
        
        Task {
            do {
                let records = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.batchFetchRecordsAsync(recordIDs: recordIDs, database: db)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(records))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func batchFetchRecordsAsync(
        recordIDs: [CKRecord.ID],
        database: CKDatabase
    ) async throws -> [CKRecord] {
        let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
        var fetchedRecords: [CKRecord] = []
        var errors: [CKRecord.ID: Error] = [:]
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    errors[recordID] = error
                    print("⚠️ Failed to fetch record \(recordID): \(error)")
                }
            }
            
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    // Even if some records failed, return what we got
                    if !errors.isEmpty {
                        print("⚠️ Batch fetch completed with \(errors.count) failures out of \(recordIDs.count)")
                    }
                    continuation.resume(returning: fetchedRecords)
                case .failure(let error):
                    // Complete failure
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    /// Batch save multiple records with partial failure handling
    func batchSaveRecords(
        _ records: [CKRecord],
        database: CKDatabase? = nil,
        completion: @escaping (Result<[CKRecord], Error>) -> Void
    ) {
        guard !records.isEmpty else {
            completion(.success([]))
            return
        }
        
        let db = database ?? publicDB
        
        Task {
            do {
                let savedRecords = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.batchSaveRecordsAsync(records, database: db)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(savedRecords))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func batchSaveRecordsAsync(
        _ records: [CKRecord],
        database: CKDatabase
    ) async throws -> [CKRecord] {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        var savedRecords: [CKRecord] = []
        var errors: [CKRecord.ID: Error] = [:]
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    errors[recordID] = error
                    print("⚠️ Failed to save record \(recordID): \(error)")
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if !errors.isEmpty {
                        print("⚠️ Batch save completed with \(errors.count) failures out of \(records.count)")
                    }
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    /// Check if CloudKit is available and the user is authenticated.
    func checkCloudKitAvailability(completion: @escaping (Result<Bool, Error>) -> Void) {
        // We can now perform a synchronous network check first.
        if !CloudKitErrorHandler.NetworkMonitor.shared.isNetworkAvailable() {
            completion(.success(false)) // Or you could return a specific error here
            return // Exit the function early if no network
        }
        
        // Use a Task for the asynchronous CloudKit call.
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.your.app.bundle.id") // Replace with your container
                let status = try await container.accountStatus()
                
                // If the network is available, we now check the account status.
                let isAvailable = (status == .available)
                
                DispatchQueue.main.async {
                    completion(.success(isAvailable))
                }
            } catch {
                // Handle specific CloudKit errors gracefully.
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .notAuthenticated:
                        // The user is not signed in to iCloud.
                        DispatchQueue.main.async {
                            completion(.success(false))
                        }
                    case .networkUnavailable, .networkFailure:
                        // Although we checked before, it's good practice to handle this error too.
                        // This can happen if the network disconnects during the async call.
                        DispatchQueue.main.async {
                            completion(.success(false))
                        }
                    default:
                        // Handle other CloudKit-specific errors.
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                } else {
                    // Handle non-CloudKit errors.
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
//    // MARK: - Network Status Check
//    
//    /// Check if CloudKit is available and the user is authenticated
//    func checkCloudKitAvailability(completion: @escaping (Result<Bool, Error>) -> Void) {
//        Task {
//            do {
//                let isAvailable = await errorHandler.checkNetworkAvailability()
//                
//                if isAvailable {
//                    // Also check account status
//                    let status = try await container.accountStatus()
//                    let available = (status == .available)
//                    
//                    DispatchQueue.main.async {
//                        completion(.success(available))
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        completion(.success(false))
//                    }
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
    
    // MARK: - Error Recovery Helpers
    
    /// Attempts to recover from a conflict error by refetching and retrying
    private func recoverFromConflict<T>(
        recordID: CKRecord.ID,
        update: @escaping (CKRecord) throws -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) where T: Any {
        Task {
            do {
                // Fetch the latest version of the record
                let record = try await publicDB.record(for: recordID)
                
                // Apply the update
                try update(record)
                
                // Save the updated record
                let savedRecord = try await publicDB.save(record)
                
                DispatchQueue.main.async {
                    completion(.success(savedRecord as! T))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Logging and Analytics
    
    private func logCloudKitOperation(
        operation: String,
        success: Bool,
        error: Error? = nil,
        metadata: [String: Any]? = nil
    ) {
        if AppDebug.isEnabled && AppDebug.cloudKit {
            let status = success ? "✅" : "❌"
            print("\(status) CloudKit Operation: \(operation)")
            
            if let error = error {
                print("   Error: \(error.localizedDescription)")
                
                // Log classified error for better debugging
                let classifiedError = errorHandler.classifyError(error)
                print("   Classified as: \(classifiedError)")
            }
            
            if let metadata = metadata {
                print("   Metadata: \(metadata)")
            }
        }
        else {
            // Not found is not an error for removal
            return
        }
        
        //try await privateDB.deleteRecord(withID: recordID)
    }
    
    // MARK: - Reactions Management with Error Handling
    
    func addReaction(
        to linkID: CKRecord.ID,
        from userID: String,
        reactionType: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.addReactionAsync(
                            to: linkID,
                            from: userID,
                            reactionType: reactionType
                        )
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func addReactionAsync(
        to linkID: CKRecord.ID,
        from userID: String,
        reactionType: String
    ) async throws {
        let predicate = NSPredicate(format: "linkID == %@ AND userID == %@", linkID.recordName, userID)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        let existingRecord = matchResults.compactMap { _, result in
            try? result.get()
        }.first
        
        if let record = existingRecord {
            // Update existing reaction
            record["reactionType"] = reactionType as CKRecordValue
            record["timestamp"] = Date() as CKRecordValue
            _ = try await publicDB.save(record)
        } else {
            // Create new reaction
            let reactionID = CKRecord.ID(recordName: UUID().uuidString)
            let record = CKRecord(recordType: "Reaction", recordID: reactionID)
            
            record["linkID"] = linkID.recordName as CKRecordValue
            record["userID"] = userID as CKRecordValue
            record["reactionType"] = reactionType as CKRecordValue
            record["timestamp"] = Date() as CKRecordValue
            
            _ = try await publicDB.save(record)
        }
    }
    
    func removeReaction(
        from linkID: CKRecord.ID,
        by userID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.removeReactionAsync(from: linkID, by: userID)
                    },
                    maxAttempts: 2
                )
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func removeReactionAsync(from linkID: CKRecord.ID, by userID: String) async throws {
        let predicate = NSPredicate(format: "linkID == %@ AND userID == %@", linkID.recordName, userID)
        let query = CKQuery(recordType: "Reaction", predicate: predicate)
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        // FIXED: Use underscore since we're not using the recordID variable
        guard let recordIDToDelete = matchResults.first?.0 else {
            // No reaction found to delete - this is not an error
            return
        }
        
        // Delete the reaction record
        try await publicDB.deleteRecord(withID: recordIDToDelete)
    }

    // MARK: - Replies
    func fetchReplies(
        for linkID: CKRecord.ID,
        completion: @escaping (Result<[Reply], Error>) -> Void
    ) {
        Task {
            do {
                let replies = try await errorHandler.performWithRetry(
                    operation: { [weak self] in
                        guard let self = self else { throw CloudKitError.invalidData("Manager deallocated") }
                        return try await self.fetchRepliesAsync(for: linkID)
                    }
                )
                DispatchQueue.main.async {
                    completion(.success(replies))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchRepliesAsync(for linkID: CKRecord.ID) async throws -> [Reply] {
        let predicate = NSPredicate(format: "linkID == %@", linkID.recordName)
        let query = CKQuery(recordType: "Reply", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 50)
        
        let replies: [Reply] = matchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Reply(record: record)
        }
        
        return replies
    }
}
