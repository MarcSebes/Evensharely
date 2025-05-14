//
//  CachedSharedLink.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/14/25.
//

import Foundation
import CloudKit

struct CachedSharedLink: Codable {
    let id: String
    let url: URL
    let senderFullName: String
    let senderIcloudID: String
    let recipientIcloudIDs: [String]
    let date: Date
    let tags: [String]
}

extension SharedLink {
    func toCacheModel() -> CachedSharedLink {
        CachedSharedLink(
            id: id.recordName,
            url: url,
            senderFullName: senderFullName,
            senderIcloudID: senderIcloudID,
            recipientIcloudIDs: recipientIcloudIDs,
            date: date,
            tags: tags
        )
    }

    static func fromCacheModel(_ cached: CachedSharedLink) -> SharedLink {
        SharedLink(
            id: CKRecord.ID(recordName: cached.id),
            url: cached.url,
            senderIcloudID: cached.senderIcloudID,
            senderFullName: cached.senderFullName,
            recipientIcloudIDs: cached.recipientIcloudIDs,
            tags: cached.tags,
            date: cached.date
        )
    }
}

struct OLDSharedLinkCache {
    private static let cacheKey = "recent_shared_links"

    static func save(_ links: [SharedLink]) {
        let recent = Array(links.prefix(20))
        let cachedLinks = recent.map { $0.toCacheModel() }
        if let data = try? JSONEncoder().encode(cachedLinks) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func load() -> [SharedLink] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedLinks = try? JSONDecoder().decode([CachedSharedLink].self, from: data) else {
            return []
        }
        return cachedLinks.map { SharedLink.fromCacheModel($0) }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

