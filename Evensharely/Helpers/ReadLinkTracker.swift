//
//  ReadLinkTracker.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//

import Foundation

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
