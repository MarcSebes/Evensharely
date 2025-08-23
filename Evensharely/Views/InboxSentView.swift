//
//  InboxSentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//
import SwiftUI
import CloudKit

struct InboxSentView: View {
    @ObservedObject var viewModel: LinkViewModel
    @ObservedObject private var preferences = AppPreferences.shared
    @Binding var tagEditingLink: SharedLink?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Links List
                if preferences.useCondensedInbox {
                    List {
                        ForEach(viewModel.sentLinks) { link in
                            SharedLinkCardCondensed(
                                link: link,
                                icloudID: viewModel.userID,
                                reactions: viewModel.reactionsByLink[link.id] ?? [],
                                isRead: true, // Sent links don't have read status
                                isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                                showReadDot: false,
                                showSender: false, // No need to show sender (it's you)
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
                        
                        if viewModel.isLoadingSent {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    List {
                        ForEach(viewModel.sentLinks) { link in
                            SharedLinkCard(
                                link: link,
                                icloudID: viewModel.userID,
                                reactions: viewModel.reactionsByLink[link.id] ?? [],
                                isRead: true, // Sent links don't have read status
                                isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                                showReadDot: false,
                                showSender: false, // No need to show sender (it's you)
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
                        
                        if viewModel.isLoadingSent {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
                // Empty state
                if viewModel.sentLinks.isEmpty && !viewModel.isLoadingSent {
                    ContentUnavailableView {
                        Label("No Sent Links", systemImage: "paperplane")
                    } description: {
                        Text("You haven't shared any links yet")
                    }
                }
            }
            .navigationTitle("Sent")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refreshSent()
            }
            .onAppear {
                if viewModel.sentLinks.isEmpty {
                    viewModel.loadSentLinks()
                }
            }
        }
    }
}

#Preview {
   
    return InboxSentView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}
