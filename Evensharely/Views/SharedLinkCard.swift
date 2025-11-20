//
//  SharedLinkCard.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI
import CloudKit

private func replyAuthorDisplay(from userID: String) -> String {
    // If you later add real names for users, swap this to look up a display name.
    // For now, show a short suffix of the userID to keep it recognizable.
    let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "Someone" }
    let suffix = String(trimmed.suffix(6))
    return "User \(suffix)"
}

struct SharedLinkCard: View {
    let useRichPreview: Bool
    let link: SharedLink
    let icloudID: String
    let reactions: [Reaction]
    let replies: [Reply]
    let isRead: Bool?
    let isFavorited: Bool
    let showReadDot: Bool
    let showSender: Bool
    let recipientText: String?
    let onOpen: () -> Void
    let onFavoriteToggle: (() -> Void)?
    let onReact: ((String) -> Void)?
    init(
            link: SharedLink,
            icloudID: String,
            reactions: [Reaction],
            replies: [Reply],
            isRead: Bool? = nil,
            isFavorited: Bool = false,
            showReadDot: Bool = false,
            showSender: Bool = true,
            recipientText: String? = nil,
            useRichPreview: Bool = false,   // ⬅️ NEW, default off for lists
            onOpen: @escaping () -> Void,
            onFavoriteToggle: (() -> Void)? = nil,
            onReact: ((String) -> Void)? = nil
        ) {
            _loader = StateObject(wrappedValue: LinkMetadataLoader(key: link.url))
        self.link = link
        self.icloudID = icloudID
        self.reactions = reactions
        self.replies = replies
        self.isRead = isRead
        self.isFavorited = isFavorited
        self.showReadDot = showReadDot
        self.showSender = showSender
        self.recipientText = recipientText
        self.useRichPreview = useRichPreview
        self.onOpen = onOpen
        self.onFavoriteToggle = onFavoriteToggle
        self.onReact = onReact
            
    }
    @StateObject private var loader: LinkMetadataLoader
    @State private var previewHeight: CGFloat = 200 // default fallback height
    @StateObject private var nameResolver = NameResolver.shared
    private var debugOn: Bool = false
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {  //need more horizontal whitespace outside this VStack
                
                // --------------------//
                //Display Header
                // --------------------//
                
                VStack {
                    HStack(alignment: .center, spacing: 10) {
                        Text(formattedDate(link.date))

                        Spacer()
                        Text(link.senderFullName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                       Spacer()
                        if showReadDot, let isRead, !isRead {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }

                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                //End Display Header
                
                Button(action: onOpen) {
                    ZStack(alignment: .topTrailing) {
                        GeometryReader { geometry in
                            let cardWidth = min(geometry.size.width, 500)
                            
                            VStack(spacing: 0) {
                                if useRichPreview {
                                    // Only use this on detail screens (outside lists)
                                    LinkPreviewPlain(previewURL: link.url, width: cardWidth, height: $previewHeight)
                                        .frame(width: cardWidth, height: previewHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(radius: 5)
                                        .padding(4)
                                } else {
                                    // Lightweight list-friendly preview (no WebKit)
                                    HStack(spacing: 12) {
                                        ZStack {
                                            if let image = loader.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                Image(systemName: "link")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                    .background(.gray.opacity(0.35))
                                            }
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(loader.metadata?.title ?? link.url.absoluteString)
                                                .font(.headline)
                                                .lineLimit(2)
                                            Text(loader.metadata?.url?.host ?? link.url.host() ?? "")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .task(id: link.id) {
                                        try? await Task.sleep(for: .milliseconds(120))
                                        await loader.load(for: link.url, existingAuthor: link.author)
                                    }
                                }
                                
                                // Debug info for sizing of preview
                                if debugOn {
                                    VStack(spacing: 0) {
                                        Text("Preview width: \(Int(cardWidth))  •  height: \(Int(previewHeight))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.bottom, 4)
                                    }
                                }
                            }
                        }
                        .frame(height: previewHeight)


                        // --------------------//
                        //Display Favorite Star Overlay
                        // --------------------//
                        if let onFavoriteToggle = onFavoriteToggle {
                            Button(action: onFavoriteToggle) {
                                Circle()
                                    .fill(isFavorited ? Color.yellow.opacity(0.9) : Color.black.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: isFavorited ? "star.fill" : "star")
                                            .foregroundColor(.white)
                                    )
                                
                                    .padding(15)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                //End Favorite Star Overlay
 
                // --------------------//
                // If in debugMode,
                // add space below it
                // --------------------//
                if debugOn {
                    VStack{
                        Spacer()
                    }
                }
                
                // End debug spacing ---//
                
                
                
                
                // --------------------//
                // Reaction Block
                // --------------------//
                HStack {
                    ForEach(["👍", "❤️", "😂", "😮"], id: \.self) { emoji in
                        let count = reactions.filter { $0.reactionType == emoji }.count
                        let userSelected = reactions.contains { $0.reactionType == emoji && $0.userID == icloudID }
                        
                        Button(action: {
                            onReact?(emoji)
                        }) {
                            Text("\(emoji) \(count)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(userSelected ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                } //End reaction Block
                .font(.caption)
                .padding()
                
                // --------------------//
                // Replies Block
                // --------------------//
                if !replies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        let topReplies = Array(replies.prefix(2))
                        ForEach(topReplies, id: \.id) { reply in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bubble.left")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    // kick off name resolution if needed
                                    let _ = nameResolver.resolveIfNeeded(userID: reply.userID)
                                    let author = nameResolver.displayName(for: reply.userID) ?? replyAuthorDisplay(from: reply.userID)

                                    // Author + text
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(author + ":")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(reply.text)
                                            .font(.subheadline)
                                    }
                                    // Timestamp
                                    Text(reply.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 16) {
                            Button("View all") { /* hook up later if needed */ }
                                .font(.caption)
                            Button("Reply") { /* hook up later; inline composer exists in InboxView */ }
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                
                // --------------------//
                //Display Tags
                // --------------------//
                if !link.tags.isEmpty {
                    HStack(alignment: .center, spacing: 10) {
                        Text("\(link.tags.joined(separator: ", "))")
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal)
                    
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }
    
    
}
    struct SharedLinkCardPreview: View {
        var body: some View {
            let linkID = CKRecord.ID(recordName: "sample-link-id")
            let userID = "_e625da7a3ca0e60d88415fa21c57927c"
            
            return SharedLinkCard(
                link: SharedLink(
                    id: linkID,
                    url: URL(string: "https://www.instagram.com/reel/DIb-jIUS63C/?utm_source=ig_web_copy_link")!,
                    senderIcloudID: "_8e6d6d95ea597e372b720835e8141fd7",
                    senderFullName: "Kelly Sebes",
                    recipientIcloudIDs: ["_e625da7a3ca0e60d88415fa21c57927c"],
                    tags: ["dogs","animals"],
                    date: Date()
                ),
                icloudID: userID,
                reactions: [
                    Reaction(id: CKRecord.ID(recordName: "reaction-2"), linkID: linkID, userID: "_e625da7a3ca0e60d88415fa21c57927c", reactionType: "❤️", timestamp: Date())
                ],
                replies: [],
                isRead: false,
                isFavorited: true,
                showReadDot: true,
                showSender: true,
                recipientText: nil,
                onOpen: { print("📬 Opened link!") },
                onFavoriteToggle: { print("⭐️ Toggled favorite!") },
                onReact: { emoji in print("Reacted with \(emoji)") }
            )
            .padding()
        }
    }


    #Preview {
        SharedLinkCardPreview()
    }

    
