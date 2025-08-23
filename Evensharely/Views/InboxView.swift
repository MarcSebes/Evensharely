//
//  InboxView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//
import SwiftUI
import CloudKit

struct InboxView: View {
    @ObservedObject var viewModel: LinkViewModel
    @ObservedObject private var preferences = AppPreferences.shared
    @Binding var tagEditingLink: SharedLink?
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $viewModel.inboxFilter) {
                    ForEach(LinkViewModel.InboxFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ZStack {
                    // Links List
                    if preferences.useCondensedInbox {
                        List {
                            ForEach(viewModel.filteredInboxLinks) { link in
                                
                                SharedLinkCardCondensed(
                                    link: link,
                                    icloudID: viewModel.userID,
                                    reactions: viewModel.reactionsByLink[link.id] ?? [],
                                    isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
                                    isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                                    showReadDot: true,
                                    showSender: true,
                                    onOpen: { viewModel.openLink(link) },
                                    onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
                                    onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
                                )
                                .onAppear {
                                    // Load more when we reach the last item
                                    if link.id == viewModel.filteredInboxLinks.last?.id,
                                       !viewModel.isLoadingInbox,
                                       !viewModel.allInboxLinksLoaded {
                                        viewModel.loadInboxLinks()
                                    }
                                }
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
                            
                            if viewModel.isLoadingInbox {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    } else {
                        List {
                            ForEach(viewModel.filteredInboxLinks) { link in
                                
                                SharedLinkCard(
                                    link: link,
                                    icloudID: viewModel.userID,
                                    reactions: viewModel.reactionsByLink[link.id] ?? [],
                                    isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
                                    isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                                    showReadDot: true,
                                    showSender: true,
                                    onOpen: { viewModel.openLink(link) },
                                    onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
                                    onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
                                )
                                .onAppear {
                                    // Load more when we reach the last item
                                    if link.id == viewModel.filteredInboxLinks.last?.id,
                                       !viewModel.isLoadingInbox,
                                       !viewModel.allInboxLinksLoaded {
                                        viewModel.loadInboxLinks()
                                    }
                                }
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
                            
                            if viewModel.isLoadingInbox {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    }
                    // Empty state
                    if viewModel.filteredInboxLinks.isEmpty && !viewModel.isLoadingInbox {
                        ContentUnavailableView {
                            Label(
                                viewModel.inboxFilter == .unread ? "No Unread Links" : "No Links",
                                systemImage: "tray"
                            )
                        } description: {
                            Text(viewModel.inboxFilter == .unread
                                ? "You've read all your shared links"
                                : "No one has shared any links with you yet")
                        } actions: {
                            Button("View All Links") {
                                viewModel.inboxFilter = .all
                            }
                        }
                        
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refreshInbox()
            }
            .onAppear {
                // Initialize with unread filter
                viewModel.inboxFilter = .unread
                
                if viewModel.inboxLinks.isEmpty {
                    viewModel.loadInboxLinks()
                }
                viewModel.loadFavorites()
            }
        }
    }
}

#Preview {
    //let previewID = "000866.c7c9a90c75834932b91822b2739c37ce.2033"
    return InboxView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}
