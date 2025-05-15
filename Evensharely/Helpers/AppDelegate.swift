//
//  AppDelegate.swift
//  Evensharely
//

import UIKit
import CloudKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        
        // Setup CloudKit subscriptions
        SubscriptionManager.shared.setupSubscriptions()
        
        return true
    }
    
    // MARK: - Remote Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Successfully registered for remote notifications
        print("📱 Successfully registered for remote notifications")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Failed to register for remote notifications
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle silent notifications (background updates)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if this is a CloudKit notification
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            print("📬 Received CloudKit notification: \(notification.notificationID.map { String(describing: $0) } ?? "unknown")")
            
            // Determine what kind of notification this is
            if notification.notificationType == .query {
                if let queryNotification = notification as? CKQueryNotification,
                   let recordID = queryNotification.recordID {
                    handleSharedLinkNotification(recordID: recordID, queryNotification: queryNotification) { result in
                        completionHandler(result)
                    }
                } else {
                    completionHandler(.failed)
                }
            } else {
                // Other notification types
                completionHandler(.noData)
            }
        } else {
            // Not a CloudKit notification
            completionHandler(.noData)
        }
    }
    
    // MARK: - Notification Handling
    
    // Process a new SharedLink notification
    private func handleSharedLinkNotification(recordID: CKRecord.ID, queryNotification: CKQueryNotification, completion: @escaping (UIBackgroundFetchResult) -> Void) {
        // Get the current user ID
        guard let userID = UserDefaults.standard.string(forKey: "evensharely_icloudID") else {
            completion(.failed)
            return
        }
        
        // Fetch the SharedLink record
        CloudKitManager.shared.publicDB.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("❌ Error fetching SharedLink: \(error.localizedDescription)")
                completion(.failed)
                return
            }
            
            guard let record = record else {
                print("❌ SharedLink record not found")
                completion(.failed)
                return
            }
            
            // Create a SharedLink from the record
            let sharedLink = SharedLink(record: record)
            
            // Update the cached links
            self.updateCachedLinks(with: sharedLink) {
                // Update the badge count
                self.updateBadgeCount(for: userID) {
                    completion(.newData)
                }
            }
        }
    }
    
    // Update the cached links with the new link
    private func updateCachedLinks(with newLink: SharedLink, completion: @escaping () -> Void) {
        // Get existing cached links
        var links = SharedLinkCache.load()
        
        // Check if the link already exists
        if !links.contains(where: { $0.id.recordName == newLink.id.recordName }) {
            // Add the new link to the beginning of the array
            links.insert(newLink, at: 0)
            
            // Save the updated cache
            SharedLinkCache.save(links)
        }
        
        completion()
    }
    
    // Update the badge count
    private func updateBadgeCount(for userID: String, completion: @escaping () -> Void) {
        // Get all links from the cache
        let links = SharedLinkCache.load()
        
        // Update the badge count
        BadgeManager.updateBadgeCount(for: links, userID: userID)
        
        completion()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification alert even when the app is in the foreground
        // Using .list and .banner instead of deprecated .alert
        completionHandler([.badge, .sound, .list, .banner])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped on a notification
        print("👆 User tapped on notification: \(response.notification.request.identifier)")
        
        // TODO: Navigate to the Inbox tab if needed
        
        completionHandler()
    }
}
