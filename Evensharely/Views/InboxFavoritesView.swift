//
//  InboxFavoritesView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//
import SwiftUI
import CloudKit

struct InboxFavoritesView: View {
    @ObservedObject var viewModel: LinkViewModel
    @ObservedObject private var preferences = AppPreferences.shared
    @Binding var tagEditingLink: SharedLink?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Links List
//                if preferences.useCondensedInbox {
                    List {
                        ForEach(viewModel.favoriteLinks) { link in
                            SharedLinkCardCondensed(
                                link: link,
                                icloudID: viewModel.userID,
                                reactions: viewModel.reactionsByLink[link.id] ?? [],
                                replies: viewModel.repliesByLink[link.id] ?? [],
                                isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
                                isFavorited: true, // Always true in this view
                                showReadDot: false,
                                showSender: true,
                                onOpen: { viewModel.openLink(link) },
                                onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
                                onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteLink(link)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    tagEditingLink = link
                                } label: {
                                    Label("Tags", systemImage: "tag")
                                }
                                .tint(.blue)
                            }
                            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                        
                        if viewModel.isLoadingFavorites {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
//                } else {
//                    List {
//                        ForEach(viewModel.favoriteLinks) { link in
//                            SharedLinkCard(
//                                link: link,
//                                icloudID: viewModel.userID,
//                                reactions: viewModel.reactionsByLink[link.id] ?? [],
//                                replies: viewModel.repliesByLink[link.id] ?? [],
//                                isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
//                                isFavorited: true,
//                                showReadDot: false,
//                                showSender: true,
//                                useRichPreview: false,   // ⬅️ keep lists lightweight
//                                onOpen: { viewModel.openLink(link) },
//                                onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
//                                onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
//                            )
//                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
//                                Button(role: .destructive) {
//                                    viewModel.deleteLink(link)
//                                } label: {
//                                    Label("Delete", systemImage: "trash")
//                                }
//                                
//                                Button {
//                                    tagEditingLink = link
//                                } label: {
//                                    Label("Tags", systemImage: "tag")
//                                }
//                                .tint(.blue)
//                            }
//                            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
//                        }
//                        
//                        if viewModel.isLoadingFavorites {
//                            ProgressView()
//                                .frame(maxWidth: .infinity, alignment: .center)
//                                .listRowSeparator(.hidden)
//                        }
//                    }
//                    .listStyle(.plain)
//                }
                
                // Empty state
                if viewModel.favoriteLinks.isEmpty && !viewModel.isLoadingFavorites {
                    ContentUnavailableView {
                        Label("No Favorites", systemImage: "star")
                    } description: {
                        Text("You haven't favorited any links yet")
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.loadFavorites()
            }
            .onAppear {
                if viewModel.favoriteLinks.isEmpty {
                    viewModel.loadFavorites()
                }
            }
        }
    }
}

#Preview {

    return InboxFavoritesView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}

