//
//  BadgeManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//
import UserNotifications

class BadgeManager {
    static func updateBadgeCount(for links: [SharedLink], userID: String) {
        let unreadCount = links.filter {
            !ReadLinkTracker.isLinkRead(linkID: $0.id.recordName, userID: userID)
        }.count

        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error = error {
                print("❌ Badge error: \(error.localizedDescription)")
            } else {
                print("✅ Badge set to \(unreadCount)")
            }
        }
    }

    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Failed to clear badge: \(error.localizedDescription)")
            }
        }
    }
}

