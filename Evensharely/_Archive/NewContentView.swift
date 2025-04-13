//
//  NewContentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//

//
//  ContentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//
/*
import SwiftUI
import CloudKit

struct NewContentView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @State private var links: [SharedLink] = []
    @State private var showUserSetup = false
    @State private var reactionsByLink: [CKRecord.ID: [Reaction]] = [:]
    private let reactionManager = ReactionManager()
    @State private var favoriteLinkIDs: Set<CKRecord.ID> = []
    @State private var loadedPages: Int = 0 // Each page = 7 days
    @State private var isLoadingMore = false
    @State private var allLinksLoaded = false
    @State private var didScroll = false

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
                    let isRead = ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: icloudID)

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

                            if !isRead {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                        Button(action: {
                            ReadLinkTracker.markAsRead(linkID: link.id.recordName, userID: icloudID)
                            if let index = links.firstIndex(where: { $0.id == link.id }) {
                                links[index] = links[index]
                                BadgeManager.updateBadgeCount(for: links, userID: icloudID)
                            }
                            UIApplication.shared.open(link.url)
                        }) {
                            ZStack(alignment: .topTrailing) {
                                LinkPreviewPlain(previewURL: link.url)
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 5)
                                    .padding(4)

                                Button(action: {
                                    triggerHapticFeedback()
                                    toggleFavorite(for: link)
                                }) {
                                    Circle()
                                        .fill(favoriteLinkIDs.contains(link.id) ? Color.yellow.opacity(0.9) : Color.black.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Image(systemName: favoriteLinkIDs.contains(link.id) ? "star.fill" : "star")
                                                .foregroundColor(.white)
                                                .font(.system(size: 14, weight: .bold))
                                        )
                                        .padding(15)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
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

                // ⬇️ Pagination Trigger: now lives OUTSIDE the loop
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
                loadedPages = 0
                allLinksLoaded = false
                links = []
                loadFavorites()
                loadLinks()
            }
            .navigationTitle("Shared with Me")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFavorites()
                loadedPages = 0
                links = []
                loadLinks()
            }
        }
    }

    func loadLinks() {
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

    func loadFavorites() {
        loadFavoritedLinks(userIcloudID: icloudID) { fetchedLinks in
            DispatchQueue.main.async {
                self.favoriteLinkIDs = Set(fetchedLinks.map { $0.id })
            }
        }
    }

    func toggleFavorite(for link: SharedLink) {
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
*/
