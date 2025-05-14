//
//  SharedLinkCache.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import Foundation
import CloudKit

/// Handles local caching of SharedLink objects for offline access
struct SharedLinkCache {
    private static let key = "evensharely_cached_links"
    
    /// Save an array of SharedLinks to UserDefaults
    static func save(_ links: [SharedLink]) {
        let encoder = JSONEncoder()
        
        // Prepare links for serialization by converting to simplified version
        let cachableLinks = links.map { link -> CachableSharedLink in
            return CachableSharedLink(
                recordName: link.id.recordName,
                url: link.url.absoluteString,
                senderIcloudID: link.senderIcloudID,
                senderFullName: link.senderFullName,
                recipientIcloudIDs: link.recipientIcloudIDs,
                tags: link.tags,
                date: link.date
            )
        }
        
        if let encoded = try? encoder.encode(cachableLinks) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    /// Load cached SharedLinks from UserDefaults
    static func load() -> [SharedLink] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        
        let decoder = JSONDecoder()
        guard let cachableLinks = try? decoder.decode([CachableSharedLink].self, from: data) else {
            return []
        }
        
        // Convert back to SharedLink objects
        return cachableLinks.map { cached -> SharedLink in
            return SharedLink(
                id: CKRecord.ID(recordName: cached.recordName),
                url: URL(string: cached.url) ?? URL(string: "https://example.com")!,
                senderIcloudID: cached.senderIcloudID,
                senderFullName: cached.senderFullName,
                recipientIcloudIDs: cached.recipientIcloudIDs,
                tags: cached.tags,
                date: cached.date
            )
        }
    }
    
    /// Clear all cached links
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// A simplified version of SharedLink that can be easily encoded to JSON
private struct CachableSharedLink: Codable {
    let recordName: String
    let url: String
    let senderIcloudID: String
    let senderFullName: String
    let recipientIcloudIDs: [String]
    let tags: [String]
    let date: Date
}
