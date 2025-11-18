// LinkMetadataLoader.swift  (replace the contents with this)

import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers

// LinkMetadataLoader.swift  — replace just the load(...) body with this version

@MainActor
final class LinkMetadataLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var image: Image?
    @Published var isLoading = false

    @Published var youtubeAuthor: String?
    
    func load(for url: URL) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // 1) Use the shared, throttled cache (limits global LP concurrency).
            let meta = try await LPMetadataCache.shared.metadata(for: url) // ⬅️ throttled/cached
            self.metadata = meta

            // 2) Try to pull a preview image if provided.
            if let preview = await loadImage(from: meta.imageProvider) {
                self.image = preview
            }
            if isYouTube(url: url) {
                youtubeAuthor = await fetchYouTubeAuthor(for: url)
            } else {
                youtubeAuthor = nil
            }
            
        } catch {
            // Keep placeholder on failure.
        }
    }

    private func loadImage(from provider: NSItemProvider?) async -> Image? {
        let imageType = UTType.image.identifier
        guard let provider, provider.hasItemConformingToTypeIdentifier(imageType) else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: imageType, options: nil) { item, _ in
                var result: Image? = nil
                if let ui = item as? UIImage {
                    result = Image(uiImage: ui)
                } else if let data = item as? Data, let ui = UIImage(data: data) {
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

private func isYouTube(url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    return host.contains("youtube.com") || host.contains("youtu.be")
}

private struct YouTubeOEmbedResponse: Decodable {
    let author_name: String?
    let title: String?
}

private func fetchYouTubeAuthor(for url: URL) async -> String? {
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
        // You might want a debug print here, but silently fail is fine for UI
        return nil
    }
}

