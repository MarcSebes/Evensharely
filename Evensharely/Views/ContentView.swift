//
//  CleanPaginatedContentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @State private var links: [SharedLink] = []
    @State private var favoriteLinkIDs: Set<CKRecord.ID> = []
    @State private var reactionsByLink: [CKRecord.ID: [Reaction]] = [:]
    @State private var loadedPages: Int = 0
    @State private var isLoadingMore = false
    @State private var allLinksLoaded = false
    @State private var didScroll = false

    private let reactionManager = ReactionManager()

    struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .global).minY)
                }
                .frame(height: 0)
                .onPreferenceChange(ScrollOffsetKey.self) { y in
                    if y < 0 {
                        didScroll = true
                    }
                }

                let sortedLinks = links.sorted(by: { $0.date > $1.date })

                ForEach(sortedLinks) { link in
                    SharedLinkCard(
                        link: link,
                        icloudID: icloudID,
                        reactions: reactionsByLink[link.id] ?? [],
                        isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: icloudID),
                        isFavorited: favoriteLinkIDs.contains(link.id),
                        showReadDot: true,
                        showSender: true,
                        onOpen: {
                            UIApplication.shared.open(link.url)
                            ReadLinkTracker.markAsRead(linkID: link.id.recordName, userID: icloudID)
                            BadgeManager.updateBadgeCount(for: links, userID: icloudID)
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
                }

                if didScroll && loadedPages > 0 && links.count >= 10 && !isLoadingMore && !allLinksLoaded {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            print("🚀 Triggering next page \(loadedPages + 1)")
                            loadLinks()
                        }
                }
            }
            .refreshable {
                resetPagination()
                loadFavorites()
                loadLinks()
            }
            .navigationTitle("Shared with Me")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                resetPagination()
                loadFavorites()
                loadLinks()
            }
        }
    }

    private func loadLinks() {
        guard !isLoadingMore else { return }
        isLoadingMore = true

        let currentPage = loadedPages
        let daysPerPage = 7
        let calendar = Calendar.current
        let now = Date()

        let startOffset = -((currentPage + 1) * daysPerPage - 1)
        let endOffset = -(currentPage * daysPerPage)

        guard let startDate = calendar.date(byAdding: .day, value: startOffset, to: now),
              let endDate = calendar.date(byAdding: .day, value: endOffset, to: now) else {
            isLoadingMore = false
            return
        }

        print("🗓️ Fetching from \(formattedDate(startDate)) to \(formattedDate(endDate))")

        CloudKitManager.shared.fetchSharedLinks(from: startDate, to: endDate) { result in
            isLoadingMore = false

            switch result {
            case .success(let fetched):
                let newLinks = fetched.filter { newLink in
                    !links.contains(where: { $0.id == newLink.id })
                }

                if newLinks.isEmpty {
                    allLinksLoaded = true
                    return
                }

                loadedPages += 1
                links.append(contentsOf: newLinks)
                links.sort(by: { $0.date > $1.date })

                Task {
                    let reactionMap = await reactionManager.loadAllReactions(for: newLinks.map { $0.id }, userID: icloudID)
                    DispatchQueue.main.async {
                        for (key, value) in reactionMap {
                            reactionsByLink[key] = value
                        }
                    }
                }

                BadgeManager.updateBadgeCount(for: links, userID: icloudID)

            case .failure(let error):
                print("❌ Failed to fetch inbox: \(error.localizedDescription)")
            }
        }
    }

    private func resetPagination() {
        loadedPages = 0
        allLinksLoaded = false
        links = []
    }

    private func loadFavorites() {
        loadFavoritedLinks(userIcloudID: icloudID) { fetchedLinks in
            DispatchQueue.main.async {
                self.favoriteLinkIDs = Set(fetchedLinks.map { $0.id })
            }
        }
    }

    private func loadReactions(for link: SharedLink) {
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

    private func userReaction(for link: SharedLink) -> String? {
        reactionsByLink[link.id]?.first(where: { $0.userID == icloudID })?.reactionType
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
}
