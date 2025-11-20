//
//  SharedLinkInboxRow.swift
//  Evensharely
//

import SwiftUI
import CloudKit

private func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.doesRelativeDateFormatting = true
    f.locale = .current
    f.dateStyle = .short
    f.timeStyle = .none
    return f.string(from: date)
}

// MARK: - Platform-aware formatting

private enum LinkPlatform {
    case instagram
    case tiktok
    case youtube
    case other
}

private struct FormattedLinkText {
    let subject: String
    let snippet: String
    let displayHost: String
}

private func cleanedHost(from url: URL) -> String {
    guard let host = url.host?.lowercased() else { return "" }

    if host.hasPrefix("www.") {
        return String(host.dropFirst(4))
    }
    return host
}

private func platform(for url: URL) -> LinkPlatform {
    guard let host = url.host?.lowercased() else { return .other }

    if host.contains("instagram.com") {
        return .instagram
    } else if host.contains("tiktok.com") {
        return .tiktok
    } else if host.contains("youtube.com") || host.contains("youtu.be") {
        return .youtube
    } else {
        return .other
    }
}

// MARK: Instagram Specific Formatting
// Example: "Saturday Night Live on Instagram: "four years in the making""
private func instagramSubject(from title: String) -> String {
    // Look specifically for " on Instagram"
    if let range = title.range(of: " on Instagram") {
        let before = title[..<range.lowerBound]
        return before.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Fallback: existing logic (everything before colon)
    if let colon = title.range(of: ":") {
        return String(title[..<colon.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return title
}

private func instagramSnippet(from title: String) -> String {
    guard let range = title.range(of: ":") else {
        return ""
    }

    var snippet = String(title[range.upperBound...])
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Strip wrapping quotes if present
    if snippet.hasPrefix("\""), snippet.hasSuffix("\""), snippet.count >= 2 {
        snippet.removeFirst()
        snippet.removeLast()
    }

    return snippet
}

// MARK: TikTok Specific Formatting
// Extract "@username" from URLs like /@username/video/123456789
private func tiktokUsername(from url: URL) -> String? {
    let components = url.path.split(separator: "/")
    guard let first = components.first, first.hasPrefix("@") else {
        return nil
    }
    return String(first)
}

private func formatTikTok(url: URL, title: String?) -> FormattedLinkText {
    let rawTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let username = tiktokUsername(from: url)

    let subject: String
    if let rawTitle, !rawTitle.isEmpty, rawTitle.lowercased() != "tiktok" {
        subject = rawTitle
    } else if let username {
        subject = "TikTok · \(username)"
    } else {
        subject = "TikTok video"
    }

    return FormattedLinkText(
        subject: subject,
        snippet: "",
        displayHost: "TikTok"
    )
}

// MARK: YouTube Specific Formatting
private func formatYouTube(url: URL, title: String?, author: String?) -> FormattedLinkText {
    let rawTitle = (title ?? url.lastPathComponent)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanedTitle: String
    if let range = rawTitle.range(of: " - YouTube", options: [.caseInsensitive, .backwards]) {
        cleanedTitle = String(rawTitle[..<range.lowerBound])
    } else {
        cleanedTitle = rawTitle
    }

    let subject = (author?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
    } ?? cleanedTitle

    return FormattedLinkText(
        subject: subject,
        snippet: cleanedTitle,
        displayHost: "YouTube"
    )
}



// MARK: Other Formatting
private func formatOther(url: URL, title: String?) -> FormattedLinkText {
    let fallback = url.absoluteString
    let resolvedTitle = title ?? fallback

    return FormattedLinkText(
        subject: resolvedTitle,
        snippet: resolvedTitle,
        displayHost: cleanedHost(from: url)   // "domain.com", no "www."
    )
}


// MARK: Master Formatter
private func formatLinkText(
    for url: URL,
    title: String?,
    cachedAuthor: String?,
    youtubeAuthor: String?
) -> FormattedLinkText {
    let platformType = platform(for: url)
    let rawTitle = title ?? url.absoluteString

    switch platformType {
    case .instagram:
        let subject = instagramSubject(from: rawTitle)
        let snippet = instagramSnippet(from: rawTitle)
        return FormattedLinkText(
            subject: subject,
            snippet: snippet,
            displayHost: "Instagram"
        )

    case .tiktok:
        return formatTikTok(url: url, title: title)

    case .youtube:
        let effectiveAuthor = cachedAuthor ?? youtubeAuthor
        return formatYouTube(url: url, title: title, author: effectiveAuthor)

    case .other:
        return formatOther(url: url, title: title)
    }
}





struct SharedLinkInboxRow: View {
    let link: SharedLink
    let isRead: Bool?
    let showReadDot: Bool
    let onOpen: () -> Void

    var onAuthorResolved: ((SharedLink, String) -> Void)? = nil
    
    @StateObject private var loader = LinkMetadataLoader()
    @State private var loadTask: Task<Void, Never>? = nil
    
    // Retrieve Platform specific formatted link text
    private var formattedText: FormattedLinkText {
        formatLinkText(
            for: link.url,
            title: loader.metadata?.title,
            cachedAuthor: link.author,               // NEW: from CloudKit
            youtubeAuthor: loader.youtubeAuthor      // NEW: from loader
        )
    }



    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {

                // Thumbnail (replaces Mail's initials circle)
                ZStack {
                    if let image = loader.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        // Lightweight placeholder while loading
                        Image(systemName: "link")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.gray.opacity(0.35))
                    }
                }
                .frame(width: 52, height: 52)
                //.clipShape(Circle())
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                .overlay {
//                    Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
//                }

                // Center stack (Sender, Title, Host)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(link.senderFullName)
                            .font(.caption.weight((isRead ?? true) ? .regular : .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        // Date at trailing edge
                        Text(shortDate(link.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if showReadDot, let isRead, !isRead {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                        }
                    }

                    // “Subject” = Title
                    Text(formattedText.subject)
                        .font((isRead ?? true) ? .body : .body.weight(.semibold))
                        .lineLimit(1)

                    // “Snippet” = Descripion
                    if !formattedText.snippet.isEmpty {
                        Text(formattedText.snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    
                    // Host (e.g. Instagram)
                    Text(formattedText.displayHost)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Debounced load kicked off per row appearance
            loadTask?.cancel()
            loadTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                await loader.load(for: link.url, existingAuthor: link.author)
            }
        }
        .onDisappear {
            // Cancel any in-flight load when the row disappears (fast scrolling, etc.)
            loadTask?.cancel()
        }
        .onChange(of: loader.youtubeAuthor) { _, newAuthor in
            guard let newAuthor = newAuthor?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newAuthor.isEmpty else { return }
            guard newAuthor != link.author else { return }   // avoid redundant writes

            onAuthorResolved?(link, newAuthor)
        }
        
    }
    
}

// Tiny helper to get host from URL without importing elsewhere
private extension URL {
    func host() -> String? { self.host }
}

