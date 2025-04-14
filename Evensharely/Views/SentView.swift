//
//  SentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI
import CloudKit

struct SentView: View {
    @AppStorage("evensharely_icloudID") private var icloudID: String = ""
    @State private var sentLinks: [SharedLink] = []
    @State private var reactionsByLink: [CKRecord.ID: [Reaction]] = [:]
    @State private var profilesByID: [String: UserProfile] = [:]
    @State private var selectedReactionDetail: ReactionDetail? = nil

    struct ReactionDetail: Identifiable {
        let id = UUID() // required for .sheet
        let emoji: String
        let names: [String]
    }

    
    private let reactionManager = ReactionManager()

    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(sentLinks.sorted(by: { $0.date > $1.date })) { link in
                  
                    SharedLinkCard(
                        link: link,
                        icloudID: icloudID,
                        reactions: reactionsByLink[link.id] ?? [],
                        isRead: nil,                     // No read tracking needed for sent links
                        isFavorited: false,             // Not relevant for SentView
                        showReadDot: false,             // No red dot
                        showSender: false,              // You are the sender
                        recipientText: recipientNames(for: link),
                        onOpen: {
                            UIApplication.shared.open(link.url)
                        },
                        onFavoriteToggle: nil,          // No need to favorite links you've sent
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
            }
            .refreshable {
                loadSentLinks()
            }
            .navigationTitle("Shared by Me" )
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !icloudID.isEmpty {
                    loadSentLinks()
                }
            }
            .sheet(item: $selectedReactionDetail) { detail in
                VStack(spacing: 12) {
                    Text("Who reacted \(detail.emoji)")
                        .font(.headline)
                    Divider()
                    ForEach(detail.names, id: \.self) { name in
                        Text(name)
                    }
                    Spacer()
                    Button("Close") {
                        selectedReactionDetail = nil
                    }
                    .padding(.top)
                }
                .padding()
            }

        }
    }

    // MARK: - Data Loading

    func loadSentLinks() {
        print("🔍 SentView: Loaded icloudID = \(icloudID)")

        CloudKitManager.shared.fetchSentLinks(for: icloudID) { result in
            switch result {
            case .success(let allLinks):
                
                print("🧾 Checking for matching links...")
                for link in allLinks {
                    print("📨 senderIcloudID: \(link.senderIcloudID)")
                    if link.senderIcloudID.contains("8e6d6d95") {
                          print("🔍 Potential match: \(link.senderIcloudID)")
                      }
                }
                 
                print("✅ Filtering using icloudID = \(icloudID)")
                let myLinks = allLinks.filter { $0.senderIcloudID == icloudID }

                print("🎯 SentView found \(myLinks.count) matching links")

                if myLinks.isEmpty {
                    print("⚠️ No matching links. Check if icloudID is stale or senderIcloudID mismatch.")
                } else {
                    for link in myLinks.prefix(3) {
                        print("🆕 Matched Link: \(link.url.absoluteString)")
                        print("   📅 Date: \(link.date)")
                    }

                    let missingDateCount = myLinks.filter {
                        $0.date == Date(timeIntervalSince1970: 0)
                    }.count

                    if missingDateCount > 0 {
                        print("⚠️ \(missingDateCount) links have invalid/missing date fields")
                    }
                }

                sentLinks = myLinks


                let allRecipientIDs = Set(myLinks.flatMap { $0.recipientIcloudIDs })
                CloudKitManager.shared.fetchUserProfiles(forIcloudIDs: Array(allRecipientIDs)) { result in
                    if case let .success(profiles) = result {
                        profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.icloudID, $0) })
                    }
                }
                print("📤 Found \(allLinks.count) links in CloudKit")

                for link in myLinks {
                    loadReactions(for: link)
                }

            case .failure(let error):
                print("❌ Error loading sent links: \(error.localizedDescription)")
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
                print("⚠️ Failed to fetch reactions for link \(link.id.recordName): \(error)")
            }
        }
    }

    // MARK: - Utilities

    func recipientNames(for link: SharedLink) -> String {
        link.recipientIcloudIDs
            .compactMap { profilesByID[$0]?.fullName }
            .joined(separator: ", ")
    }

    func uniqueReactionTypes(from reactions: [Reaction]) -> [String] {
        Array(Set(reactions.map(\.reactionType))).sorted()
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
