import Foundation
import CloudKit
import Combine

// Represents a cached user entry (id is the Apple user ID)
public struct CachedUser: Codable, Equatable, Identifiable {
    public let id: String
    public var fullName: String
}

// App Group-backed lightweight cache for name lookups
public enum ProfileCache {
    private static let suiteName = "group.com.marcsebes.evensharely"
    private static let cacheKey  = "evensharely_cachedUsers"

    public static func save(_ users: [CachedUser]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: cacheKey)
        UserDefaults(suiteName: suiteName)?.synchronize()
    }

    public static func load() -> [CachedUser] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: cacheKey),
              let users = try? JSONDecoder().decode([CachedUser].self, from: data) else {
            return []
        }
        return users
    }
}

// Observable name resolver that uses ProfileCache first, then CloudKit
@MainActor
final class NameResolver: ObservableObject {
    static let shared = NameResolver()
    private init() {}

    @Published private(set) var names: [String: String] = [:] // userID -> fullName

    // Preload from ProfileCache on first access
    private var loadedFromCache = false

    private func ensureLoadedFromCache() {
        guard !loadedFromCache else { return }
        let cached = ProfileCache.load()
        for user in cached {
            names[user.id] = user.fullName
        }
        loadedFromCache = true
    }

    func displayName(for userID: String) -> String? {
        ensureLoadedFromCache()
        return names[userID]
    }

    func resolveIfNeeded(userID: String) {
        ensureLoadedFromCache()
        if names[userID] != nil { return }

        // Attempt a background fetch and cache
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let profiles = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[UserProfile], Error>) in
                    CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: [userID]) { result in
                        switch result {
                        case .success(let profiles): continuation.resume(returning: profiles)
                        case .failure(let error): continuation.resume(throwing: error)
                        }
                    }
                }

                guard let profile = profiles.first else { return }
                let name = profile.fullName

                // Update in-memory map
                await MainActor.run {
                    self.names[userID] = name
                }

                // Merge into ProfileCache
                var existing = ProfileCache.load()
                if let idx = existing.firstIndex(where: { $0.id == userID }) {
                    existing[idx].fullName = name
                } else {
                    existing.append(CachedUser(id: userID, fullName: name))
                }
                ProfileCache.save(existing)
            } catch {
                // Silently ignore; UI will keep fallback
            }
        }
    }
}
