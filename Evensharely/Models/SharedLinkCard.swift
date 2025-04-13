//
//  SharedLinkCard.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI
import CloudKit

struct SharedLinkCard: View {
    let link: SharedLink
    let icloudID: String
    let reactions: [Reaction]
    let profilesByID: [String: UserProfile]
    let onReact: ((String) -> Void)?  // now FIRST of the optional group
    let onReactionTap: ((String, [String]) -> Void)?
    let isRead: Bool?

    init(
        link: SharedLink,
        icloudID: String,
        reactions: [Reaction],
        profilesByID: [String: UserProfile],
        onReact: ((String) -> Void)? = nil,
        onReactionTap: ((String, [String]) -> Void)? = nil,
        isRead: Bool? = nil
    ) {
        self.link = link
        self.icloudID = icloudID
        self.reactions = reactions
        self.profilesByID = profilesByID
        self.onReact = onReact
        self.onReactionTap = onReactionTap
        self.isRead = isRead
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formattedDate(link.date))
                Spacer()
                if !link.tags.isEmpty {
                    Text(link.tags.joined(separator: ", "))
                        .font(.caption2)
                }
                Spacer()
                Text(senderOrRecipientsText())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let isRead, !isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.horizontal)

            LinkPreviewPlain(previewURL: link.url)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)
                .padding(4)

            // Reactions
            if !reactions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(uniqueReactionTypes(), id: \.self) { emoji in
                        let filtered = reactions.filter { $0.reactionType == emoji }
                        let count = filtered.count
                        let userSelected = filtered.contains { $0.userID == icloudID }

                        Button(action: {
                            if let onReactionTap = onReactionTap {
                                let names = filtered.map { profilesByID[$0.userID]?.fullName ?? "Unknown" }
                                onReactionTap(emoji, names)
                            } else if let onReact = onReact {
                                onReact(emoji)
                            }
                        }) {
                            Text("\(emoji) \(count)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(userSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .font(.caption)
                .padding(.horizontal)
            } else {
                Text("No reactions yet")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }

            Divider()
        }
        .padding(.top, 8)
    }

    func senderOrRecipientsText() -> String {
        if link.senderIcloudID == icloudID {
            return "To: \(link.recipientIcloudIDs.compactMap { profilesByID[$0]?.fullName }.joined(separator: ", "))"
        } else {
            return link.senderFullName
        }
    }

    func uniqueReactionTypes() -> [String] {
        Array(Set(reactions.map(\.reactionType))).sorted()
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

