//
//  SharedLinkCard.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI
import CloudKit

struct SharedLinkCard: View {
    let link: SharedLink
    let icloudID: String
    let reactions: [Reaction]
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
        isRead: Bool? = nil,
        isFavorited: Bool = false,
        showReadDot: Bool = false,
        showSender: Bool = true,
        recipientText: String? = nil,
        onOpen: @escaping () -> Void,
        onFavoriteToggle: (() -> Void)? = nil,
        onReact: ((String) -> Void)? = nil
    ) {
        self.link = link
        self.icloudID = icloudID
        self.reactions = reactions
        self.isRead = isRead
        self.isFavorited = isFavorited
        self.showReadDot = showReadDot
        self.showSender = showSender
        self.recipientText = recipientText
        self.onOpen = onOpen
        self.onFavoriteToggle = onFavoriteToggle
        self.onReact = onReact
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if showReadDot, let isRead, !isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 4)
                }

                Text(formattedDate(link.date))
                Spacer()
                if !link.tags.isEmpty {
                    Text(link.tags.joined(separator: ", "))
                        .font(.caption2)
                }
                Spacer()
                if showSender {
                    Text(link.senderFullName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let recipientText {
                    Text(recipientText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.horizontal)

            Button(action: onOpen) {
                ZStack(alignment: .topTrailing) {
                    LinkPreviewPlain(previewURL: link.url)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                        .padding(4)

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
            }
            .font(.caption)
            .padding(.horizontal)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }


    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

