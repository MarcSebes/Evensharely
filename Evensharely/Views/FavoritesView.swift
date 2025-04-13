//
//  FavoritesView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI
import CloudKit

struct FavoritesView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @State private var links: [SharedLink] = []
    @State private var reactionsByLink: [CKRecord.ID: [Reaction]] = [:]
    private let reactionManager = ReactionManager()

    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(links.sorted(by: { $0.date > $1.date })) { link in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(formattedDate(link.date))
                            Spacer()
                            if !link.tags.isEmpty {
                                Text(link.tags.joined(separator: ", "))
                                    .font(.caption2)
                            }
                            Spacer()
                            Text(link.senderFullName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                        Button(action: {
                            UIApplication.shared.open(link.url)
                        }) {
                            LinkPreviewPlain(previewURL: link.url)
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 5)
                                .padding(4)
                        }
                        .buttonStyle(PlainButtonStyle())

                        HStack {
                            ForEach(["👍", "❤️", "😂", "😮"], id: \.self) { emoji in
                                let count = reactionsByLink[link.id]?.filter { $0.reactionType == emoji }.count ?? 0
                                let userSelected = userReaction(for: link) == emoji

                                Button(action: {
                                    Task {
                                        do {
                                            try await reactionManager.addOrUpdateReaction(linkID: link.id, userID: icloudID, reactionType: emoji)
                                            loadReactions(for: link)
                                        } catch {
                                            print("❌ Failed to react: \(error)")
                                        }
                                    }
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
                    .padding(.vertical, 4)
                }
                .padding()
            }
            .refreshable {
                loadFavorites()
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFavorites()
            }
        }
    }

    func loadFavorites() {
        loadFavoritedLinks(userIcloudID: icloudID) { fetchedLinks in
            DispatchQueue.main.async {
                self.links = fetchedLinks
                for link in fetchedLinks {
                    self.loadReactions(for: link)
                }
            }
        }
    }

    func loadReactions(for link: SharedLink) {
        Task {
            do {
                let reactions = try await reactionManager.fetchReactions(for: link.id)
                DispatchQueue.main.async {
                    reactionsByLink[link.id] = reactions
                }
            } catch {
                print("⚠️ Failed to fetch reactions: \(error)")
            }
        }
    }

    func userReaction(for link: SharedLink) -> String? {
        reactionsByLink[link.id]?.first(where: { $0.userID == icloudID })?.reactionType
    }
}

