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
    @State private var favoriteLinkIDs: Set<CKRecord.ID> = []

    var body: some View {
        NavigationView {
            ScrollView {
                if links.isEmpty {
                    VStack(spacing: 16) {
                        Image("AppIcon")
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("You Don't Have Any Favorites Yet! Don't worry, SquirrelBear can be your favorite friend!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ForEach(links.sorted(by: { $0.date > $1.date })) { link in
                        SharedLinkCard(
                            link: link,
                            icloudID: icloudID,
                            reactions: reactionsByLink[link.id] ?? [],
                            isRead: nil,
                            isFavorited: favoriteLinkIDs.contains(link.id),
                            showReadDot: false,
                            showSender: true,
                            onOpen: {
                                UIApplication.shared.open(link.url)
                            },
                            onFavoriteToggle: {
                                toggleFavorite(for: link)
                            },
                            onReact: { emoji in
                                Task {
                                    try? await reactionManager.addOrUpdateReaction(linkID: link.id, userID: icloudID, reactionType: emoji)
                                    loadReactions(for: link)
                                }
                            }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    } //end foreach
                    .padding()
                }
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

    private func toggleFavorite(for link: SharedLink) {
        let privateDB = CloudKitConfig.container.privateCloudDatabase
        let linkReference = CKRecord.Reference(recordID: link.id, action: .none)

        if favoriteLinkIDs.contains(link.id) {
            let predicate = NSPredicate(format: "userIcloudID == %@ AND linkReference == %@", icloudID, linkReference)
            let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)

            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .failure(let error):
                    print("❌ Failed to query for FavoriteLink to delete: \(error)")
                case .success(let (matchResults, _)):
                    if let recordID = matchResults.first?.0 {
                        privateDB.delete(withRecordID: recordID) { _, error in
                            if let error = error {
                                print("❌ Error deleting FavoriteLink: \(error)")
                            } else {
                                DispatchQueue.main.async {
                                    favoriteLinkIDs.remove(link.id)
                                    links.removeAll { $0.id == link.id }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            let favorite = FavoriteLink(userIcloudID: icloudID, linkReference: linkReference)
            let record = favorite.toRecord()

            privateDB.save(record) { _, error in
                if let error = error {
                    print("❌ Error saving FavoriteLink: \(error)")
                } else {
                    DispatchQueue.main.async {
                        favoriteLinkIDs.insert(link.id)
                    }
                }
            }
        }
    }
    
    func userReaction(for link: SharedLink) -> String? {
        reactionsByLink[link.id]?.first(where: { $0.userID == icloudID })?.reactionType
    }
}

