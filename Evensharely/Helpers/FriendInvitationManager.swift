//
//  FriendInvitationManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//
import Foundation
import CloudKit
import UIKit

/// Manages friend invitations in the app
class FriendInvitationManager {
    static let shared = FriendInvitationManager()
    
    private let invitationCodeLength = 8
    private let invitationCodePrefix = "ES" // Evensharely prefix
    private let invitationExpiryDays = 7 // Codes expire after 7 days
    
    // MARK: - Generate Invitation
    
    /// Generates a unique invitation code for the current user
    func generateInvitationCode(for userID: String) -> String {
        // Create a unique code with prefix + random alphanumeric
        let randomPart = UUID().uuidString.prefix(invitationCodeLength - invitationCodePrefix.count)
            .uppercased()
            .replacingOccurrences(of: "-", with: "")
        
        let code = "\(invitationCodePrefix)\(randomPart)"
        
        // Store the code in CloudKit for later verification
        storeInvitationCode(code: code, fromUserID: userID)
        
        return code
    }
    
    /// Stores the invitation code in CloudKit
    private func storeInvitationCode(code: String, fromUserID: String) {
        let invitationID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "FriendInvitation", recordID: invitationID)
        
        record["code"] = code
        record["fromUserID"] = fromUserID
        record["createdAt"] = Date()
        
        // Store as 0 (integer) for maximum compatibility
        record["isUsed"] = 0
        
        CloudKitManager.shared.publicDB.save(record) { savedRecord, error in
            if let error = error {
                print("[APPLOG] ❌ Error saving invitation code: \(error.localizedDescription)")
            } else {
                print("[APPLOG]✅ Invitation code saved successfully: \(code)")
            }
        }
    }
    
    // MARK: - Share Invitation
    
    /// Creates and shares an invitation message via the system share sheet
    func shareInvitation(code: String, from viewController: UIViewController, completion: @escaping () -> Void) {
        let message = """
        Join me on Evensharely! 
        
        Use this invitation code to connect: \(code)
        
        Download Evensharely from the App Store: https://apps.apple.com/app/evensharely/id123456789
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        // For iPad support (prevents crash on iPad)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                       y: viewController.view.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                print("[APPLOG] Invitation shared successfully")
                completion()
            }
        }
        
        // Using the main window's rootViewController to present
        DispatchQueue.main.async {
            viewController.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Accept Invitation
    
    /// Accepts a friend invitation code
    func acceptInvitation(code: String, byUserID userID: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use the updated verification method
        lookupInvitationCode(code) { result in
            switch result {
            case .success(let invitationInfo):
                // Code is valid, create friendship connection
                self.createFriendshipConnection(fromUserID: invitationInfo.fromUserID, toUserID: userID) { friendResult in
                    switch friendResult {
                    case .success:
                        // Mark the invitation as used - use the alternative method
                        self.alternativeMarkInvitationAsUsed(invitationInfo.record)
                        
                        // Return the friend's userID
                        completion(.success(invitationInfo.fromUserID))
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Helper struct to pass invitation information
    private struct InvitationInfo {
        let record: CKRecord
        let fromUserID: String
    }
    
    /// Direct lookup method for invitation codes
    private func lookupInvitationCode(_ code: String, completion: @escaping (Result<InvitationInfo, Error>) -> Void) {
        // Clean and standardize the code format
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Create a CKQuery directly without predicate
        let query = CKQuery(recordType: "FriendInvitation", predicate: NSPredicate(format: "code == %@", cleanCode))
        
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["code", "fromUserID", "isUsed", "createdAt"]
        operation.resultsLimit = 1
        
        var matchingRecords: [CKRecord] = []
        
        // Process each matching record
        operation.recordMatchedBlock = { recordID, result in
            if case .success(let record) = result {
                matchingRecords.append(record)
            }
        }
        
        // Handle the query completion
        operation.queryResultBlock = { result in
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }
            
            guard let invitation = matchingRecords.first else {
                completion(.failure(NSError(
                    domain: "FriendInvitation",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid or expired invitation code"]
                )))
                return
            }
            
            // Check if invitation is already used
            let isUsed: Bool
            if let usedNum = invitation["isUsed"] as? NSNumber {
                isUsed = usedNum.boolValue
            } else if let usedInt = invitation["isUsed"] as? Int {
                isUsed = usedInt != 0
            } else {
                isUsed = false
            }
            
            if isUsed {
                completion(.failure(NSError(
                    domain: "FriendInvitation",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "This invitation code has already been used"]
                )))
                return
            }
            
            // Check if invitation is expired
            if let createdAt = invitation["createdAt"] as? Date {
                let expiryTimeInterval = TimeInterval(self.invitationExpiryDays * 24 * 60 * 60)
                if abs(createdAt.timeIntervalSinceNow) > expiryTimeInterval {
                    completion(.failure(NSError(
                        domain: "FriendInvitation",
                        code: 410,
                        userInfo: [NSLocalizedDescriptionKey: "Invitation code has expired"]
                    )))
                    return
                }
            }
            
            // Get friend ID
            guard let fromUserID = invitation["fromUserID"] as? String else {
                completion(.failure(NSError(
                    domain: "FriendInvitation",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid invitation data"]
                )))
                return
            }
            
            // Return the valid invitation info
            let info = InvitationInfo(record: invitation, fromUserID: fromUserID)
            completion(.success(info))
        }
        
        // Execute the operation
        CloudKitManager.shared.publicDB.add(operation)
    }
    
    /// Alternative method to mark invitation as used
    func alternativeMarkInvitationAsUsed(_ originalRecord: CKRecord) {
        print("[APPLOG] 📝 Starting alternative method to mark invitation as used")
        
        // Get the record ID from the original record
        let recordID = originalRecord.recordID
        
        // Create a fresh stub record with just the ID and type
        let stubRecord = CKRecord(recordType: "FriendInvitation", recordID: recordID)
        
        // Set only the field we want to update
        stubRecord["isUsed"] = 1
        
        print("[APPLOG]📝 Created stub record with ID: \(recordID.recordName)")
        
        // Create a modification operation with just the changed field
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [stubRecord], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .changedKeys
        
        // Handle the result
        modifyOperation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                print("[APPLOG]✅ Successfully marked invitation as used using alternative method")
            case .failure(let error):
                print("[APPLOG]❌ Alternative method failed: \(error.localizedDescription)")
                
                // As a last resort, try direct field update
                self.lastResortMarkAsUsed(recordID)
            }
        }
        
        // Execute the operation
        CloudKitManager.shared.publicDB.add(modifyOperation)
    }
    
    /// Last resort method using direct field update
    private func lastResortMarkAsUsed(_ recordID: CKRecord.ID) {
        print("[APPLOG]🔄 Attempting last resort method")
        
        // Fetch the record fresh from the database
        CloudKitManager.shared.publicDB.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("[APPLOG]❌ Failed to fetch record for last resort update: \(error.localizedDescription)")
                return
            }
            
            guard let record = record else {
                print("[APPLOG]❌ Record not found for last resort update")
                return
            }
            
            // Try to update using a string value instead of a number
            record["isUsed"] = "true"
            
            // Save using allKeys policy
            CloudKitManager.shared.publicDB.save(record) { _, error in
                if let error = error {
                    print("[APPLOG]❌ Last resort failed: \(error.localizedDescription)")
                } else {
                    print("[APPLOG]✅ Last resort succeeded")
                }
            }
        }
    }
    
    // MARK: - Create Friendship
    
    /// Creates a bidirectional friendship connection between two users
    private func createFriendshipConnection(fromUserID: String, toUserID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Add toUserID to fromUser's friends list
        group.enter()
        addFriend(userID: fromUserID, friendID: toUserID) { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        // Add fromUserID to toUser's friends list
        group.enter()
        addFriend(userID: toUserID, friendID: fromUserID) { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                // Refresh profile cache
                self.refreshProfileCache(userIDs: [fromUserID, toUserID])
                completion(.success(()))
            } else {
                completion(.failure(errors.first!))
            }
        }
    }
    
    /// Adds a friend to a user's friends list
    private func addFriend(userID: String, friendID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Fetch the user's profile
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: userID) { result in
            switch result {
            case .success(let profile):
                // Check if already friends
                var friends = profile.friends
                if !friends.contains(friendID) {
                    friends.append(friendID)
                    
                    // Update the user's profile
                    let record = profile.toRecord(with: profile.image)
                    record["friends"] = friends as CKRecordValue
                    
                    CloudKitManager.shared.publicDB.save(record) { _, error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    // Already friends, consider it a success
                    completion(.success(()))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Refreshes the profile cache for the given user IDs
    private func refreshProfileCache(userIDs: [String]) {
        // Fetch the user profiles
        CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: userIDs) { result in
            switch result {
            case .success(let profiles):
                // Convert to the format expected by ProfileCache
                let cachedUsers = profiles.map { profile in
                    CachedUser(id: profile.appleUserID, fullName: profile.fullName)
                }
                
                // Get existing cached users
                var existingUsers = ProfileCache.load()
                
                // Update or add new users
                for cachedUser in cachedUsers {
                    if let index = existingUsers.firstIndex(where: { $0.id == cachedUser.id }) {
                        existingUsers[index] = cachedUser
                    } else {
                        existingUsers.append(cachedUser)
                    }
                }
                
                // Save back to cache
                ProfileCache.save(existingUsers)
                
            case .failure(let error):
                print("[APPLOG] ❌ Error refreshing profile cache: \(error.localizedDescription)")
            }
        }
    }
}

extension FriendInvitationManager {
    
    // MARK: - Simplified Approach
    
    /// A completely different approach to handling invitation acceptance
    /// Instead of modifying the invitation record, we'll create a new "UsedInvitation" record
    func simplifiedAcceptInvitation(code: String, byUserID userID: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("[APPLOG] Starting simplified invitation acceptance for code: \(code)")
        
        // Clean the code
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Step 1: Check if this code exists and is valid
        let query = CKQuery(recordType: "FriendInvitation", predicate: NSPredicate(format: "code == %@", cleanCode))
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 1
        
        var matchingInvitation: CKRecord?
        var fromUserID: String?
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                matchingInvitation = record
                fromUserID = record["fromUserID"] as? String
            }
        }
        
        operation.queryResultBlock = { result in
            guard let invitationRecord = matchingInvitation, let friendID = fromUserID else {
                print("[APPLOG] ❌ No valid invitation found with code: \(cleanCode)")
                completion(.failure(NSError(
                    domain: "FriendInvitation",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid or expired invitation code"]
                )))
                return
            }
            
            // Step 2: Check if we already have a "UsedInvitation" record for this code
            self.checkIfInvitationUsed(code: cleanCode) { isUsed in
                if isUsed {
                    print("[APPLOG] ❌ Invitation code already used: \(cleanCode)")
                    completion(.failure(NSError(
                        domain: "FriendInvitation",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "This invitation code has already been used"]
                    )))
                    return
                }
                
                // Step 3: Create the friendship connection
                self.createFriendshipConnection(fromUserID: friendID, toUserID: userID) { connectionResult in
                    switch connectionResult {
                    case .success:
                        // Step 4: Create a separate record to mark the invitation as used
                        self.markInvitationAsUsedWithNewRecord(code: cleanCode) { markResult in
                            switch markResult {
                            case .success:
                                print("[APPLOG] ✅ Successfully processed invitation")
                                completion(.success(friendID))
                                
                            case .failure(let error):
                                print("[APPLOG] ⚠️ Friendship created but failed to mark invitation: \(error.localizedDescription)")
                                // Still consider it a success since the friendship was created
                                completion(.success(friendID))
                            }
                        }
                        
                    case .failure(let error):
                        print("[APPLOG] ❌ Failed to create friendship: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
        }
        
        CloudKitManager.shared.publicDB.add(operation)
    }
    
    /// Check if an invitation code has already been used
    private func checkIfInvitationUsed(code: String, completion: @escaping (Bool) -> Void) {
        let query = CKQuery(recordType: "UsedInvitation", predicate: NSPredicate(format: "code == %@", code))
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 1
        
        var foundRecord = false
        
        operation.recordMatchedBlock = { _, _ in
            foundRecord = true
        }
        
        operation.queryResultBlock = { _ in
            completion(foundRecord)
        }
        
        CloudKitManager.shared.publicDB.add(operation)
    }
    
    /// Mark an invitation as used by creating a new record type
    private func markInvitationAsUsedWithNewRecord(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Create a new record to track used invitations
        let record = CKRecord(recordType: "UsedInvitation")
        record["code"] = code
        record["usedAt"] = Date()
        
        CloudKitManager.shared.publicDB.save(record) { _, error in
            if let error = error {
                print("[APPLOG] ❌ Failed to save UsedInvitation record: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("[APPLOG] ✅ Successfully created UsedInvitation record for code: \(code)")
                completion(.success(()))
            }
        }
    }
}


extension FriendInvitationManager {
    
    /// Improved friend addition method that avoids insert errors
    func improvedAddFriend(userID: String, friendID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[APPLOG] Adding friend \(friendID) to user \(userID)")
        
        // Fetch the user's profile
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: userID) { result in
            switch result {
            case .success(let profile):
                // Check if already friends
                var friends = profile.friends
                
                // If already friends, just return success
                if friends.contains(friendID) {
                    print("[APPLOG] Already friends, skipping update")
                    completion(.success(()))
                    return
                }
                
                // Add the new friend
                friends.append(friendID)
                
                // Create a modify operation with only the friends field
                let recordID = profile.id
                
                // Create a stub record with just the ID and the friends field
                let stubRecord = CKRecord(recordType: "UserProfile", recordID: recordID)
                stubRecord["friends"] = friends as CKRecordValue
                
                // Use a modification operation with changed keys policy
                let modifyOperation = CKModifyRecordsOperation(recordsToSave: [stubRecord], recordIDsToDelete: nil)
                modifyOperation.savePolicy = .changedKeys
                
                modifyOperation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("[APPLOG] ✅ Successfully added friend")
                        completion(.success(()))
                    case .failure(let error):
                        print("[APPLOG] ❌ Failed to add friend: \(error.localizedDescription)")
                        
                        // Try the last resort method if this fails
                        self.lastResortAddFriend(profile: profile, friendID: friendID, completion: completion)
                    }
                }
                
                CloudKitManager.shared.publicDB.add(modifyOperation)
                
            case .failure(let error):
                print("[APPLOG] ❌ Failed to fetch profile: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Last resort method to add a friend
    private func lastResortAddFriend(profile: UserProfile, friendID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[APPLOG] 🔄 Attempting last resort method to add friend")
        
        // Fetch the record fresh
        CloudKitManager.shared.publicDB.fetch(withRecordID: profile.id) { record, error in
            if let error = error {
                print("[APPLOG] ❌ Failed to fetch fresh record: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let record = record else {
                print("[APPLOG] ❌ Record not found")
                completion(.failure(NSError(domain: "FriendInvitation", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])))
                return
            }
            
            // Get current friends array
            var friends = record["friends"] as? [String] ?? []
            
            // Check if already friends
            if friends.contains(friendID) {
                print("[APPLOG] Already friends (last resort check)")
                completion(.success(()))
                return
            }
            
            // Add the friend
            friends.append(friendID)
            record["friends"] = friends as CKRecordValue
            
            // Save with all keys policy
            CloudKitManager.shared.publicDB.save(record) { _, error in
                if let error = error {
                    print("[APPLOG] ❌ Last resort friend add failed: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("[APPLOG] ✅ Last resort friend add succeeded")
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Improved friendship connection creator that uses the new methods
    func improvedCreateFriendshipConnection(fromUserID: String, toUserID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Add toUserID to fromUser's friends list
        group.enter()
        improvedAddFriend(userID: fromUserID, friendID: toUserID) { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        // Add fromUserID to toUser's friends list
        group.enter()
        improvedAddFriend(userID: toUserID, friendID: fromUserID) { result in
            if case .failure(let error) = result {
                errors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                // Refresh profile cache
                self.refreshProfileCache(userIDs: [fromUserID, toUserID])
                completion(.success(()))
            } else {
                completion(.failure(errors.first!))
            }
        }
    }
    
    /// Updated simplified approach that uses the improved friendship creation
    func finalizedAcceptInvitation(code: String, byUserID userID: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("[APPLOG] Starting finalized invitation acceptance for code: \(code)")
        
        // Clean the code
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Step 1: Check if this code exists and is valid
        let query = CKQuery(recordType: "FriendInvitation", predicate: NSPredicate(format: "code == %@", cleanCode))
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 1
        
        var matchingInvitation: CKRecord?
        var fromUserID: String?
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                matchingInvitation = record
                fromUserID = record["fromUserID"] as? String
            }
        }
        
        operation.queryResultBlock = { result in
            guard let invitationRecord = matchingInvitation, let friendID = fromUserID else {
                print("[APPLOG] ❌ No valid invitation found with code: \(cleanCode)")
                completion(.failure(NSError(
                    domain: "FriendInvitation",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid or expired invitation code"]
                )))
                return
            }
            
            // Step 2: Check if we already have a "UsedInvitation" record for this code
            self.checkIfInvitationUsed(code: cleanCode) { isUsed in
                if isUsed {
                    print("[APPLOG] ❌ Invitation code already used: \(cleanCode)")
                    completion(.failure(NSError(
                        domain: "FriendInvitation",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "This invitation code has already been used"]
                    )))
                    return
                }
                
                // Step 3: Create the friendship connection
                self.improvedCreateFriendshipConnection(fromUserID: friendID, toUserID: userID) { connectionResult in
                    switch connectionResult {
                    case .success:
                        // Step 4: Create a separate record to mark the invitation as used
                        self.markInvitationAsUsedWithNewRecord(code: cleanCode) { markResult in
                            switch markResult {
                            case .success:
                                print("[APPLOG] ✅ Successfully processed invitation")
                                completion(.success(friendID))
                                
                            case .failure(let error):
                                print("[APPLOG] ⚠️ Friendship created but failed to mark invitation: \(error.localizedDescription)")
                                // Still consider it a success since the friendship was created
                                completion(.success(friendID))
                            }
                        }
                        
                    case .failure(let error):
                        print("[APPLOG] ❌ Failed to create friendship: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
        }
        
        CloudKitManager.shared.publicDB.add(operation)
    }
}
