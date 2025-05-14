//
//  BadgeManager.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//
import UserNotifications

class BadgeManager {
    static func updateBadgeCount(for links: [SharedLink], userID: String) {
        if AppDebug.isEnabled && AppDebug.badge {
            print("APPLOGGED: Updating badge count...")
        }

        let unreadCount = links.filter {
            !ReadLinkTracker.isLinkRead(linkID: $0.id.recordName, userID: userID)
        }.count

        if AppDebug.isEnabled && AppDebug.badge {
            print("APPLOGGED: 🔢 Total links: \(links.count)")
            print("APPLOGGED: 🔴 Unread links: \(unreadCount)")
        }

        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if AppDebug.isEnabled && AppDebug.badge {
                if let error = error {
                    print("❌ Badge error: \(error.localizedDescription)")
                } else {
                    print("✅ Badge set to \(unreadCount)")
                }
            }
        }
    }

    static func clearBadge() {
        if AppDebug.isEnabled && AppDebug.badge {
            print("APPLOGGED: Clearing badge count...")
        }

        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if AppDebug.isEnabled && AppDebug.badge, let error = error {
                print("❌ Failed to clear badge: \(error.localizedDescription)")
            }
        }
    }
}
