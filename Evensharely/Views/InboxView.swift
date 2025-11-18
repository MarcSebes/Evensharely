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
    
    @State private var activeReplyLinkID: CKRecord.ID?
    @State private var inlineReplyDraft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $viewModel.inboxFilter) {
                    ForEach(LinkViewModel.InboxFilter.allCases) { (filter: LinkViewModel.InboxFilter) in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)

                ZStack {
                    inboxListCondensed
                    

                    if viewModel.filteredInboxLinks.isEmpty && !viewModel.isLoadingInbox {
                        InboxEmptyState(filter: viewModel.inboxFilter) {
                            viewModel.inboxFilter = .all
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

    // MARK: - List Builders

    private var inboxListCondensed: some View {
        List {
            ForEach(viewModel.filteredInboxLinks) { link in
                InboxRowCondensed(
                    link: link,
                    userID: viewModel.userID,
                    reactions: viewModel.reactionsByLink[link.id] ?? [],
                    replies: viewModel.repliesByLink[link.id] ?? [],
                    isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
                    isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                    onOpen: { viewModel.openLink(link) },
                    onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
                    onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) },
                    onReply: { activeReplyLinkID = link.id; inlineReplyDraft = "" },
                    onDelete: { viewModel.deleteLink(link) },
                    onEditTags: { tagEditingLink = link }
                )
                .onAppear {
                    if link.id == viewModel.filteredInboxLinks.last?.id,
                       !viewModel.isLoadingInbox,
                       !viewModel.allInboxLinksLoaded {
                        viewModel.loadInboxLinks()
                    }
                }

                if activeReplyLinkID == link.id {
                    InlineComposer(
                        text: $inlineReplyDraft,
                        onSend: { text in
                            let vm = viewModel
                            vm.sendInlineReply(text, to: link)
                            inlineReplyDraft = ""
                            activeReplyLinkID = nil
                        },
                        onCancel: {
                            inlineReplyDraft = ""
                            activeReplyLinkID = nil
                        }
                    )
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if viewModel.isLoadingInbox {
                LoadingRow()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

//    private var inboxListRegular: some View {
//        List {
//            ForEach(viewModel.filteredInboxLinks) { link in
//                InboxRowRegular(
//                    link: link,
//                    userID: viewModel.userID,
//                    reactions: viewModel.reactionsByLink[link.id] ?? [],
//                    replies: viewModel.repliesByLink[link.id] ?? [],
//                    isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
//                    isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
//                    onOpen: { viewModel.openLink(link) },
//                    onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
//                    onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) },
//                    onDelete: { viewModel.deleteLink(link) },
//                    onEditTags: { tagEditingLink = link }
//                )
//                .onAppear {
//                    if link.id == viewModel.filteredInboxLinks.last?.id,
//                       !viewModel.isLoadingInbox,
//                       !viewModel.allInboxLinksLoaded {
//                        viewModel.loadInboxLinks()
//                    }
//                }
//            }
//
//            if viewModel.isLoadingInbox {
//                LoadingRow()
//                    .listRowSeparator(.hidden)
//            }
//        }
//        .listStyle(.plain)
//    }
}

#Preview {
    let previewID = "PREVIEW_USER_ID"
    return InboxView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}

struct InlineComposer: View {
    @Binding var text: String
    var onSend: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Reply…", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button(action: { onSend(text) }) {
                Image(systemName: "paperplane.fill")
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel") { onCancel() }
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}

private struct InboxEmptyState: View {
    let filter: LinkViewModel.InboxFilter
    let onViewAll: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                filter == .unread ? "No Unread Links" : "No Links",
                systemImage: "tray"
            )
        } description: {
            Text(filter == .unread
                 ? "You've read all your shared links"
                 : "No one has shared any links with you yet")
        } actions: {
            Button("View All Links") { onViewAll() }
        }
    }
}

private struct LoadingRow: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct InboxRowCondensed: View {
    let link: SharedLink
    let userID: String
    let reactions: [Reaction]
    let replies: [Reply]
    let isRead: Bool
    let isFavorited: Bool
    let onOpen: () -> Void
    let onFavoriteToggle: () -> Void
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onEditTags: () -> Void

    var body: some View {
        SharedLinkCardCondensed(
            link: link,
            icloudID: userID,
            reactions: reactions,
            replies: replies,
            isRead: isRead,
            isFavorited: isFavorited,
            showReadDot: true,
            showSender: true,
            onOpen: onOpen,
            onFavoriteToggle: onFavoriteToggle,
            onReact: onReact
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            
            Button {
                onReact("❤️")
            } label: {
                Label("Love", systemImage: "heart")
            }
            .tint(.pink)


            
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .tint(.blue)

        }
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

private struct InboxRowRegular: View {
    let link: SharedLink
    let userID: String
    let reactions: [Reaction]
    let replies: [Reply]
    let isRead: Bool
    let isFavorited: Bool
    let onOpen: () -> Void
    let onFavoriteToggle: () -> Void
    let onReact: (String) -> Void
    let onDelete: () -> Void
    let onEditTags: () -> Void

    var body: some View {
        SharedLinkCard(
            link: link,
            icloudID: userID,
            reactions: reactions,
            replies: replies,
            isRead: isRead,
            isFavorited: isFavorited,
            showReadDot: true,
            showSender: true,
            recipientText: nil,
            useRichPreview: false,     // ⬅️ important for list performance
            onOpen: onOpen,
            onFavoriteToggle: onFavoriteToggle,
            onReact: onReact
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEditTags) {
                Label("Tags", systemImage: "tag")
            }
            .tint(.blue)
        }
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

