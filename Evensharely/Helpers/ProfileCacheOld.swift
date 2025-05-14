//
//  ProfileCache.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/9/25.
//

import Foundation

/// All keys under your App-Group
enum ProfileCacheOld {
  static let suiteName = "group.com.marcsebes.evensharely"
  static let cacheKey  = "evensharely_userProfiles"

  /// Persist an array of UserProfile into the App-Group UserDefaults
  static func save(_ profiles: [UserProfile]) {
    guard let data = try? JSONEncoder().encode(profiles) else { return }
    UserDefaults(suiteName: suiteName)?
      .set(data, forKey: cacheKey)
  }

  /// Load cached UserProfiles (or empty array)
  static func load() -> [UserProfile] {
    guard
      let data = UserDefaults(suiteName: suiteName)?
        .data(forKey: cacheKey),
      let profiles = try? JSONDecoder().decode([UserProfile].self, from: data)
    else {
      return []
    }
    return profiles
  }
}

