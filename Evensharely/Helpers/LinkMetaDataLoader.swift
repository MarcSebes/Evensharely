import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers

@MainActor
final class LinkMetadataLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var image: Image?
    @Published var isLoading = false
    @Published var youtubeAuthor: String?

    // Per-app-session caches
    private static var metadataCache: [URL: LPLinkMetadata] = [:]
    private static var imageCache: [URL: Image] = [:]
    private static var youtubeAuthorCache: [URL: String] = [:]

    /// Load metadata + thumbnail image for a URL.
    /// - Parameter existingAuthor: cached author (e.g. from SharedLink.author). If present,
    ///   we skip the YouTube oEmbed author fetch and just mirror this into `youtubeAuthor`.
    func load(for url: URL, existingAuthor: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Reset per-load state
        self.metadata = nil
        self.image = nil

        // Only clear youtubeAuthor if we *know* this URL isn't YouTube
        if !isYouTube(url: url) {
            self.youtubeAuthor = nil
        }

        // ---- 1) Resolve metadata, using in-memory cache first ----
        let resolvedMetadata: LPLinkMetadata
        if let cached = LinkMetadataLoader.metadataCache[url] {
            resolvedMetadata = cached
        } else {
            do {
                let fetched = try await fetchMetadata(for: url)
                LinkMetadataLoader.metadataCache[url] = fetched
                resolvedMetadata = fetched
            } catch {
                print("LinkMetadataLoader error for \(url): \(error)")
                return
            }
        }

        self.metadata = resolvedMetadata

        // ---- 2) Resolve image, also with a cache ----
        if let cachedImage = LinkMetadataLoader.imageCache[url] {
            self.image = cachedImage
        } else if let preview = await loadFirstImage(from: resolvedMetadata) {
            self.image = preview
            LinkMetadataLoader.imageCache[url] = preview
        }

        // ---- 3) YouTube author logic (unchanged in behavior) ----
        guard isYouTube(url: url) else { return }

        if let existingAuthor,
           !existingAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // We already have a cached author in SharedLink
            self.youtubeAuthor = existingAuthor

        } else if let cachedAuthor = LinkMetadataLoader.youtubeAuthorCache[url] {
            // We've already fetched this author in this app session
            self.youtubeAuthor = cachedAuthor

        } else if let fetched = await fetchYouTubeAuthor(for: url) {
            self.youtubeAuthor = fetched
            LinkMetadataLoader.youtubeAuthorCache[url] = fetched
        } else {
            self.youtubeAuthor = nil
        }
    }
}

// MARK: - LPMetadata fetch

@MainActor
private extension LinkMetadataLoader {
    func fetchMetadata(for url: URL) async throws -> LPLinkMetadata {
        // LPMetadataProvider is a one-shot object: create a fresh one per fetch.
        let provider = LPMetadataProvider()

        return try await withCheckedThrowingContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "LinkMetadataLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No metadata and no error returned"]
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Image loading helpers

@MainActor
private extension LinkMetadataLoader {
    func loadFirstImage(from metadata: LPLinkMetadata) async -> Image? {
        // Prefer the main image, fall back to icon
        if let main = await image(from: metadata.imageProvider) {
            return main
        }
        if let icon = await image(from: metadata.iconProvider) {
            return icon
        }
        return nil
    }

    func image(from provider: NSItemProvider?) async -> Image? {
        guard let provider else { return nil }

        // Easiest path: load UIImage directly if possible
        if provider.canLoadObject(ofClass: UIImage.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { item, _ in
                    guard let uiImage = item as? UIImage else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: Image(uiImage: uiImage))
                }
            }
        }

        // Fallback: load raw data / file URL for an image type
        let typeIdentifier = UTType.image.identifier

        return await withCheckedContinuation { continuation in
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                continuation.resume(returning: nil)
                return
            }

            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                var result: Image? = nil

                if let ui = item as? UIImage {
                    result = Image(uiImage: ui)
                } else if let data = item as? Data,
                          let ui = UIImage(data: data) {
                    result = Image(uiImage: ui)
                } else if let url = item as? URL,
                          let data = try? Data(contentsOf: url),
                          let ui = UIImage(data: data) {
                    result = Image(uiImage: ui)
                }

                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - YouTube author via oEmbed

private struct YouTubeOEmbedResponse: Decodable {
    let author_name: String?
}

@MainActor
private extension LinkMetadataLoader {
    func isYouTube(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }

    func fetchYouTubeAuthor(for url: URL) async -> String? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let requestURL = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: requestURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(YouTubeOEmbedResponse.self, from: data)
            return decoded.author_name
        } catch {
            // print("YouTube oEmbed error: \(error)")
            return nil
        }
    }
}
