//
//  SearchView.swift
//  Evensharely
//
//  Created by Codex on 2/2/26.
//

import SwiftUI
import CloudKit

struct SearchView: View {
    @ObservedObject var viewModel: LinkViewModel
    @Binding var tagEditingLink: SharedLink?

    @State private var query: String = ""

    private var searchTerms: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0 == "," }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchTerms.isEmpty {
                    ContentUnavailableView {
                        Label("Search Tags", systemImage: "magnifyingglass")
                    } description: {
                        Text("Type a tag to search across Inbox and Sent")
                    }
                } else if allResultsEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No links matched your tag search")
                    }
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search tags")
            .onAppear {
                if viewModel.inboxLinks.isEmpty {
                    viewModel.loadInboxLinks()
                }
                if viewModel.sentLinks.isEmpty {
                    viewModel.loadSentLinks()
                }
                viewModel.loadFavorites()
            }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        List {
            if !inboxAndMatches.isEmpty {
                Section("Inbox • Best matches") {
                    ForEach(inboxAndMatches) { link in
                        searchRow(for: link, source: .inbox)
                    }
                }
            }

            if !inboxOrOnlyMatches.isEmpty {
                Section("Inbox • Other results") {
                    ForEach(inboxOrOnlyMatches) { link in
                        searchRow(for: link, source: .inbox)
                    }
                }
            }

            if !sentAndMatches.isEmpty {
                Section("Sent • Best matches") {
                    ForEach(sentAndMatches) { link in
                        searchRow(for: link, source: .sent)
                    }
                }
            }

            if !sentOrOnlyMatches.isEmpty {
                Section("Sent • Other results") {
                    ForEach(sentOrOnlyMatches) { link in
                        searchRow(for: link, source: .sent)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private enum LinkSource {
        case inbox
        case sent
    }

    @ViewBuilder
    private func searchRow(for link: SharedLink, source: LinkSource) -> some View {
        SharedLinkCardCondensed(
            link: link,
            icloudID: viewModel.userID,
            reactions: viewModel.reactionsByLink[link.id] ?? [],
            replies: viewModel.repliesByLink[link.id] ?? [],
            isRead: source == .sent ? true : ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
            isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
            showReadDot: source == .inbox,
            showSender: source == .inbox,
            onOpen: { viewModel.openLink(link) },
            onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
            onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                tagEditingLink = link
            } label: {
                Label("Tags", systemImage: "tag")
            }
            .tint(.blue)
        }
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    // MARK: - Match Logic

    private var inboxAndMatches: [SharedLink] {
        viewModel.inboxLinks.filter(matchesAllTerms)
    }

    private var inboxOrOnlyMatches: [SharedLink] {
        let andIDs = Set(inboxAndMatches.map(\.id))
        return viewModel.inboxLinks.filter(matchesAnyTerm).filter { !andIDs.contains($0.id) }
    }

    private var sentAndMatches: [SharedLink] {
        viewModel.sentLinks.filter(matchesAllTerms)
    }

    private var sentOrOnlyMatches: [SharedLink] {
        let andIDs = Set(sentAndMatches.map(\.id))
        return viewModel.sentLinks.filter(matchesAnyTerm).filter { !andIDs.contains($0.id) }
    }

    private var allResultsEmpty: Bool {
        inboxAndMatches.isEmpty &&
        inboxOrOnlyMatches.isEmpty &&
        sentAndMatches.isEmpty &&
        sentOrOnlyMatches.isEmpty
    }

    private func matchesAllTerms(_ link: SharedLink) -> Bool {
        let tags = TagPolicy.visibleTags(from: link.tags).map { $0.lowercased() }
        guard !tags.isEmpty, !searchTerms.isEmpty else { return false }
        return searchTerms.allSatisfy { term in
            tags.contains { $0.contains(term) }
        }
    }

    private func matchesAnyTerm(_ link: SharedLink) -> Bool {
        let tags = TagPolicy.visibleTags(from: link.tags).map { $0.lowercased() }
        guard !tags.isEmpty, !searchTerms.isEmpty else { return false }
        return searchTerms.contains { term in
            tags.contains { $0.contains(term) }
        }
    }
}

#Preview {
    SearchView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}
