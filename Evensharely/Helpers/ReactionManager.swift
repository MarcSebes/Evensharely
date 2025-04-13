//
//  ReactionManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import CloudKit

class ReactionManager {
    private let container = CloudKitConfig.container
    private let database = CloudKitConfig.container.publicCloudDatabase
    private let reactionRecordType = "Reaction"

    // MARK: - Create or Update Reaction
    func addOrUpdateReaction(linkID: CKRecord.ID, userID: String, reactionType: String) async throws {
        let existing = try await fetchUserReaction(for: linkID, userID: userID)
        
        if let record = existing {
            // Update existing
            record["reactionType"] = reactionType
            record["timestamp"] = Date()
            try await database.save(record)
        } else {
            // Create new
            let record = CKRecord(recordType: reactionRecordType)
            record["link"] = CKRecord.Reference(recordID: linkID, action: .none)
            record["userID"] = userID
            record["reactionType"] = reactionType
            record["timestamp"] = Date()
            try await database.save(record)
        }
    }

    // MARK: - Delete Reaction
    func deleteReaction(for linkID: CKRecord.ID, userID: String) async throws {
        if let record = try await fetchUserReaction(for: linkID, userID: userID) {
            try await database.deleteRecord(withID: record.recordID)
        }
    }

    // MARK: - Fetch Reactions for Link
    func fetchReactions(for linkID: CKRecord.ID) async throws -> [Reaction] {
        let reference = CKRecord.Reference(recordID: linkID, action: .none)
        let predicate = NSPredicate(format: "link == %@", reference)
        let query = CKQuery(recordType: reactionRecordType, predicate: predicate)

        let (matchResults, _) = try await database.records(matching: query)
        return matchResults.compactMap { _, result in
            switch result {
            case .success(let record):
                return Reaction(
                    id: record.recordID,
                    linkID: linkID,
                    userID: record["userID"] as? String ?? "",
                    reactionType: record["reactionType"] as? String ?? "",
                    timestamp: record["timestamp"] as? Date ?? Date()
                )
            case .failure:
                return nil
            }
        }
    }

    // MARK: - Fetch Current User’s Reaction
    func fetchUserReaction(for linkID: CKRecord.ID, userID: String) async throws -> CKRecord? {
        let reference = CKRecord.Reference(recordID: linkID, action: .none)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "link == %@", reference),
            NSPredicate(format: "userID == %@", userID)
        ])
        let query = CKQuery(recordType: reactionRecordType, predicate: predicate)
        let (matchResults, _) = try await database.records(matching: query)

        return matchResults.compactMap { _, result in
            switch result {
            case .success(let record): return record
            default: return nil
            }
        }.first
    }
    
    
    
}
extension ReactionManager {
    func loadAllReactions(for linkIDs: [CKRecord.ID], userID: String? = nil) async -> [CKRecord.ID: [Reaction]] {
        guard !linkIDs.isEmpty else { return [:] }

        let linkReferences = linkIDs.map { CKRecord.Reference(recordID: $0, action: .none) }
        let predicate: NSPredicate

        if let userID = userID {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "link IN %@", linkReferences),
                NSPredicate(format: "userID == %@", userID)
            ])
        } else {
            predicate = NSPredicate(format: "link IN %@", linkReferences)
        }

        let query = CKQuery(recordType: reactionRecordType, predicate: predicate)

        do {
            let (matchResults, _) = try await database.records(matching: query)

            var result: [CKRecord.ID: [Reaction]] = [:]

            for (_, match) in matchResults {
                switch match {
                case .success(let record):
                    guard let linkRef = record["link"] as? CKRecord.Reference else { continue }

                    let reaction = Reaction(
                        id: record.recordID,
                        linkID: linkRef.recordID,
                        userID: record["userID"] as? String ?? "",
                        reactionType: record["reactionType"] as? String ?? "",
                        timestamp: record["timestamp"] as? Date ?? Date()
                    )

                    result[linkRef.recordID, default: []].append(reaction)

                case .failure(let error):
                    print("⚠️ Failed to load a reaction: \(error)")
                }
            }

            return result

        } catch {
            print("❌ Batch reaction load failed: \(error)")
            return [:]
        }
    }
}



import Foundation
import Combine

class ReactionTracker: ObservableObject {
    @Published var newReactionsExist: Bool = false
    @Published var unseenReactionCount: Int = 0

    private let seenKey = "evensharely_seenReactionIDs"

    /// Checks if there are any new unseen reactions.
    func checkForNewReactions(_ reactions: [Reaction]) {
        let seen = Set(UserDefaults.standard.array(forKey: seenKey) as? [String] ?? [])
        let unseen = reactions.filter { !seen.contains($0.id.recordName) }

        DispatchQueue.main.async {
            self.newReactionsExist = !unseen.isEmpty
            self.unseenReactionCount = unseen.count
        }
    }

    /// Marks the provided reactions as seen and clears the badge.
    func markReactionsAsSeen(_ reactions: [Reaction]) {
        let seenIDs = reactions.map { $0.id.recordName }
        var seen = Set(UserDefaults.standard.array(forKey: seenKey) as? [String] ?? [])
        seen.formUnion(seenIDs)
        UserDefaults.standard.set(Array(seen), forKey: seenKey)

        DispatchQueue.main.async {
            self.newReactionsExist = false
            self.unseenReactionCount = 0
        }
    }

    /// Clears all seen reaction tracking. (For debugging or logout)
    func reset() {
        UserDefaults.standard.removeObject(forKey: seenKey)
        DispatchQueue.main.async {
            self.newReactionsExist = false
            self.unseenReactionCount = 0
        }
    }
}
