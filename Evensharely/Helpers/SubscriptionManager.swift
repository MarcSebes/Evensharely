//
//  SubscriptionManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/14/25.
//


import CloudKit
import UserNotifications

class SubscriptionManager {
    static let shared = SubscriptionManager()
    private init() {}
    
    // MARK: - Setup Subscriptions
    
    /// Create all required subscriptions when the app launches
    func setupSubscriptions() {
        // First check if we're signed in
        guard let userID = UserDefaults.standard.string(forKey: "evensharely_icloudID"),
              !userID.isEmpty else {
            print("📝 No user signed in, skipping subscription setup")
            return
        }
        
        // Create subscription to track new shared links
        createSharedLinkSubscription(for: userID)
    }
    
    // MARK: - Shared Link Subscription
    
    /// Create a subscription to be notified when a new SharedLink is created with this user as a recipient
    private func createSharedLinkSubscription(for userID: String) {
        // Define the query predicate to match any SharedLink where this user is a recipient
        let predicate = NSPredicate(format: "recipientIcloudIDs CONTAINS %@", userID)
        
        // Create a unique ID for the subscription
        let subscriptionID = "sharedlink-\(userID)"
        
        // Create the subscription
        let subscription = CKQuerySubscription(
            recordType: "SharedLink",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        
        // Configure the notification that will be delivered
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // For silent notifications
        notificationInfo.shouldBadge = true // Update the app badge
        notificationInfo.alertBody = "You've received a new shared link" // User visible text
        notificationInfo.soundName = "default" // Play the default sound
        subscription.notificationInfo = notificationInfo
        
        // Save the subscription to CloudKit
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: []
        )
        
        operation.qualityOfService = .utility
        
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("✅ Successfully created SharedLink subscription for user \(userID)")
            case .failure(let error):
                print("❌ Failed to create SharedLink subscription: \(error.localizedDescription)")
                
                if let ckError = error as? CKError {
                    if ckError.code == .serverRejectedRequest || ckError.code == .permissionFailure {
                        print("⚠️ Permission issue with subscription. User may need to enable notifications.")
                    }
                }
            }
        }
        
        // Add the operation to the database
        CloudKitManager.shared.publicDB.add(operation)
    }
    
    // MARK: - Delete Subscriptions
    
    /// Delete all subscriptions when a user signs out
    func deleteAllSubscriptions() {
        // Get user ID from defaults
        guard let userID = UserDefaults.standard.string(forKey: "evensharely_icloudID"),
              !userID.isEmpty else {
            return
        }
        
        // Specific subscription IDs to delete
        let subscriptionIDs = [
            "sharedlink-\(userID)"
        ]
        
        // Create the operation to delete subscriptions
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [],
            subscriptionIDsToDelete: subscriptionIDs
        )
        
        operation.qualityOfService = .utility
        
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("✅ Successfully deleted all subscriptions for user \(userID)")
            case .failure(let error):
                print("❌ Failed to delete subscriptions: \(error.localizedDescription)")
            }
        }
        
        // Add the operation to the database
        CloudKitManager.shared.publicDB.add(operation)
    }
    
    // MARK: - Debug
    
    /// Debug function to list all active subscriptions
    func listAllSubscriptions() {
        let operation = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        
        operation.fetchSubscriptionCompletionBlock = { subscriptionsResult, error in
            if let error = error {
                print("❌ Error fetching subscriptions: \(error.localizedDescription)")
                return
            }
            
            guard let subscriptions = subscriptionsResult, !subscriptions.isEmpty else {
                print("📝 No active subscriptions found")
                return
            }
            
            print("📝 Found \(subscriptions.count) active subscriptions:")
            for (id, subscription) in subscriptions {
                print("  - \(id): \(subscription)")
            }
        }
        
        CloudKitManager.shared.publicDB.add(operation)
    }
}
