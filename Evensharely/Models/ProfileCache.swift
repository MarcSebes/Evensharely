//
//  ProfileCache.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/11/25.
//

import Foundation

struct CachedUser: Codable, Identifiable {
    let id: String      // appleUserID
    let fullName: String
}

enum ProfileCache {
    private static let suite = UserDefaults(suiteName: "group.com.marcsebes.evensharely")!
    private static let friendsKey = "evensharely_cachedUsers"

    static func save(_ friends: [CachedUser]) {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        suite.set(data, forKey: friendsKey)
    }

    static func load() -> [CachedUser] {
        guard let data = suite.data(forKey: friendsKey),
              let list = try? JSONDecoder().decode([CachedUser].self, from: data)
        else { return [] }
        return list
    }
}
