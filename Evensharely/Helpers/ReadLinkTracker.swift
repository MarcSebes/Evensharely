//
//  ReadLinkTracker.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//

import Foundation

/// Handles tracking of which links have been read by each user
class ReadLinkTracker {
    /// Key format: "{userID}-{linkID}"
    private static let readLinksKey = "evensharely_read_links"
    
    /// Marks a link as read by a specific user
    static func markAsRead(linkID: String, userID: String) {
        let key = makeKey(linkID: linkID, userID: userID)
        var readLinks = getReadLinks()
        readLinks.insert(key)
        saveReadLinks(readLinks)
    }
    
    /// Checks if a link has been read by a specific user
    static func isLinkRead(linkID: String, userID: String) -> Bool {
        let key = makeKey(linkID: linkID, userID: userID)
        let readLinks = getReadLinks()
        return readLinks.contains(key)
    }
    
    /// Marks a link as unread for a specific user
    static func markAsUnread(linkID: String, userID: String) {
        let key = makeKey(linkID: linkID, userID: userID)
        var readLinks = getReadLinks()
        readLinks.remove(key)
        saveReadLinks(readLinks)
    }
    
    /// Generate a combined key for UserDefaults storage
    private static func makeKey(linkID: String, userID: String) -> String {
        return "\(userID)-\(linkID)"
    }
    
    /// Load the set of read links from UserDefaults
    private static func getReadLinks() -> Set<String> {
        let defaults = UserDefaults.standard
        let array = defaults.array(forKey: readLinksKey) as? [String] ?? []
        return Set(array)
    }
    
    /// Save the set of read links to UserDefaults
    private static func saveReadLinks(_ readLinks: Set<String>) {
        let defaults = UserDefaults.standard
        defaults.set(Array(readLinks), forKey: readLinksKey)
    }
    
    /// Get all link IDs that have been read by a specific user
    static func getAllReadLinkIDs(for userID: String) -> [String] {
        let readLinks = getReadLinks()
        return readLinks
            .filter { $0.hasPrefix("\(userID)-") }
            .map { $0.replacingOccurrences(of: "\(userID)-", with: "") }
    }
    
    /// Clear all read status for all users (for debugging/testing)
    static func clearAllReadStatus() {
        print("[APPLOG]: Attempting to Clear All Read Status....")
        UserDefaults.standard.removeObject(forKey: readLinksKey)
        print("[APPLOG]: Read Status Cleared!")
    }
    
    static func markAllAsRead(links: [SharedLink], userID: String) {
        var readLinks = getReadLinks()
        
        for link in links {
            let key = makeKey(linkID: link.id.recordName, userID: userID)
            readLinks.insert(key)
        }
        
        saveReadLinks(readLinks)
        
        // Update badge count
        BadgeManager.clearBadge()
    }
}



/*
 /// Old ReadLinkTracker
class ReadLinkTracker {
    static func markAsRead(linkID: String, userID: String) {
        let key = keyFor(linkID: linkID, userID: userID)
        UserDefaults.standard.set(true, forKey: key)
    }

    static func isLinkRead(linkID: String, userID: String) -> Bool {
        let key = keyFor(linkID: linkID, userID: userID)
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func keyFor(linkID: String, userID: String) -> String {
        return "read_\(userID)_\(linkID)"
    }
}
*/
