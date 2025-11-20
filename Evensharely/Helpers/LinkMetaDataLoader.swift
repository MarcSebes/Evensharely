//
//  LinkMetaDataLoader.swift
//  Evensharely
//
//  Created by Marc Sebes on 12/22/24.
//

import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

@MainActor
final class LinkMetadataLoader: ObservableObject {

    // MARK: - Identity
    let key: URL

    // MARK: - Published Properties
    @Published var metadata: LPLinkMetadata?
    @Published var image: Image?
    @Published var isLoading = false
    @Published var youtubeAuthor: String?

    // MARK: - Static Caches (Memory)
    private static var titleCache: [URL: String] = [:]
    private static var imageDataCache: [URL: Data] = [:]
    private static var youtubeAuthorCache: [URL: String] = [:]

    // MARK: - Persistent Cache Keys
    private static let titleCacheKey = "LinkMetadataLoader.titleCache.v1"
    private static let imageCacheKey = "LinkMetadataLoader.imageCache.v1"
    private static var didLoadPersistentCaches = false

    // MARK: - Load persistent caches once
    private static func loadPersistentCachesIfNeeded() {
        guard !didLoadPersistentCaches else { return }
        didLoadPersistentCaches = true

        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard

        // Load persisted titles
        if let data = defaults.data(forKey: titleCacheKey),
           let stored = try? decoder.decode([String: String].self, from: data) {
            var dict: [URL: String] = [:]
            for (urlString, title) in stored {
                if let url = URL(string: urlString) {
                    dict[url] = title
                }
            }
            titleCache = dict
        }

        // Load persisted images
        if let data = defaults.data(forKey: imageCacheKey),
           let stored = try? decoder.decode([String: Data].self, from: data) {
            var dict: [URL: Data] = [:]
            for (urlString, dataValue) in stored {
                if let url = URL(string: urlString) {
                    dict[url] = dataValue
                }
            }
            imageDataCache = dict
        }
    }

    private static func persistTitleCache() {
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        let stringDict = Dictionary(uniqueKeysWithValues: titleCache.map { ($0.key.absoluteString, $0.value) })
        if let encoded = try? encoder.encode(stringDict) {
            defaults.set(encoded, forKey: titleCacheKey)
        }
    }

    private static func persistImageCache() {
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        let stringDict = Dictionary(uniqueKeysWithValues: imageDataCache.map { ($0.key.absoluteString, $0.value) })
        if let encoded = try? encoder.encode(stringDict) {
            defaults.set(encoded, forKey: imageCacheKey)
        }
    }

    // MARK: - Initializer
    init(key: URL) {
        self.key = key

        // Load persistent caches if needed
        LinkMetadataLoader.loadPersistentCachesIfNeeded()

        // ✨ Pre-hydrate from cache so no "flash" occurs
        if let cachedTitle = LinkMetadataLoader.titleCache[key] {
            let meta = LPLinkMetadata()
            meta.originalURL = key
            meta.url = key
            meta.title = cachedTitle
            self.metadata = meta
        }

        if let data = LinkMetadataLoader.imageDataCache[key],
           let uiImg = UIImage(data: data) {
            self.image = Image(uiImage: uiImg)
        }
    }

    // MARK: - Public Load API
    func load(for url: URL, existingAuthor: String? = nil) async {

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // ---- 0) If metadata already loaded for this URL → fast return ----
        if let meta = metadata,
           meta.originalURL == url || meta.url == url {
            // Still update YouTube author if needed
            if isYouTube(url: url) {
                if let existingAuthor,
                   !existingAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.youtubeAuthor = existingAuthor
                } else if let cachedAuthor = LinkMetadataLoader.youtubeAuthorCache[url] {
                    self.youtubeAuthor = cachedAuthor
                }
            }
            return
        }

        // ---- 1) Fast path: cached values exist ----
        if let cachedTitle = LinkMetadataLoader.titleCache[key] {
            let meta = LPLinkMetadata()
            meta.originalURL = key
            meta.url = key
            meta.title = cachedTitle
            self.metadata = meta

            if let imgData = LinkMetadataLoader.imageDataCache[key],
               let uimg = UIImage(data: imgData) {
                self.image = Image(uiImage: uimg)
            }

            // YouTube handling
            if isYouTube(url: key) {
                if let existingAuthor,
                   !existingAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.youtubeAuthor = existingAuthor
                } else if let cached = LinkMetadataLoader.youtubeAuthorCache[key] {
                    self.youtubeAuthor = cached
                } else if let fetched = await fetchYouTubeAuthor(for: key) {
                    self.youtubeAuthor = fetched
                    LinkMetadataLoader.youtubeAuthorCache[key] = fetched
                }
            }

            return
        }

        // ---- 2) Slow path: first-ever fetch ----
        self.metadata = nil
        self.image = nil

        do {
            let fetchedMeta = try await fetchMetadata(for: url)
            self.metadata = fetchedMeta

            if let title = fetchedMeta.title {
                LinkMetadataLoader.titleCache[key] = title
                LinkMetadataLoader.persistTitleCache()
            }

            if let preview = await loadFirstImage(from: fetchedMeta, for: key) {
                self.image = preview
            }

            // YouTube handling
            if isYouTube(url: key) {
                if let existingAuthor,
                   !existingAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.youtubeAuthor = existingAuthor
                } else if let cached = LinkMetadataLoader.youtubeAuthorCache[key] {
                    self.youtubeAuthor = cached
                } else if let fetched = await fetchYouTubeAuthor(for: key) {
                    self.youtubeAuthor = fetched
                    LinkMetadataLoader.youtubeAuthorCache[key] = fetched
                }
            }

        } catch {
            print("LinkMetadataLoader error for \(url): \(error)")
        }
    }

    // MARK: - LP Metadata Provider (One-shot)

    private func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        let provider = LPMetadataProvider() // one-shot, must create new each time

        return try await withCheckedThrowingContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing:
                        NSError(domain: "LinkMetadataLoader",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Metadata fetch failed"])
                    )
                }
            }
        }
    }

    // MARK: - Image Loading

    private func loadFirstImage(from metadata: LPLinkMetadata, for url: URL) async -> Image? {

        if let main = await image(from: metadata.imageProvider, for: url) {
            return main
        }

        if let icon = await image(from: metadata.iconProvider, for: url) {
            return icon
        }

        return nil
    }

    private func image(from provider: NSItemProvider?, for url: URL) async -> Image? {
        guard let provider else { return nil }

        // Load UIImage directly if possible
        if provider.canLoadObject(ofClass: UIImage.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { item, _ in
                    guard let uiImage = item as? UIImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let data = uiImage.pngData()
                    if let data {
                        LinkMetadataLoader.imageDataCache[url] = data
                        LinkMetadataLoader.persistImageCache()
                    }

                    continuation.resume(returning: Image(uiImage: uiImage))
                }
            }
        }

        // Load raw data otherwise
        let typeIdentifier = UTType.image.identifier

        return await withCheckedContinuation { continuation in
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                continuation.resume(returning: nil)
                return
            }

            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                var uiImage: UIImage?
                var data: Data?

                if let img = item as? UIImage {
                    uiImage = img
                    data = img.pngData()
                } else if let d = item as? Data {
                    uiImage = UIImage(data: d)
                    data = d
                } else if let urlValue = item as? URL,
                          let d = try? Data(contentsOf: urlValue) {
                    uiImage = UIImage(data: d)
                    data = d
                }

                if let uiImage, let data {
                    LinkMetadataLoader.imageDataCache[url] = data
                    LinkMetadataLoader.persistImageCache()
                }

                continuation.resume(
                    returning: uiImage.map { Image(uiImage: $0) }
                )
            }
        }
    }

    // MARK: - YouTube Author Fetching

    private struct YouTubeOEmbedResponse: Decodable {
        let author_name: String?
    }

    private func isYouTube(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    private func fetchYouTubeAuthor(for url: URL) async -> String? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let finalURL = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: finalURL)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(YouTubeOEmbedResponse.self, from: data)
            return decoded.author_name
        } catch {
            return nil
        }
    }
}
