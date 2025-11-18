import SwiftUI
import CloudKit

struct InboxRecipeView: View {
    @ObservedObject var viewModel: LinkViewModel
    @Binding var tagEditingLink: SharedLink?

    @State private var activeReplyLinkID: CKRecord.ID?
    @State private var inlineReplyDraft: String = ""
    @State private var filter: LinkViewModel.InboxFilter = .unread

    // MARK: - Derived Data
    private var recipeLinks: [SharedLink] {
        viewModel.inboxLinks.filter { $0.tags.contains(filterTag.recipe.rawValue) }
    }

    private var filteredRecipeLinks: [SharedLink] {
        switch filter {
        case .unread:
            return recipeLinks.filter { !ReadLinkTracker.isLinkRead(linkID: $0.id.recordName, userID: viewModel.userID) }
        case .all:
            return recipeLinks
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker (Unread / All)
                Picker("Filter", selection: $filter) {
                    ForEach(LinkViewModel.InboxFilter.allCases) { (f: LinkViewModel.InboxFilter) in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)

                ZStack {
                    recipeListCondensed

                    if filteredRecipeLinks.isEmpty && !viewModel.isLoadingInbox {
                        RecipeEmptyState(filter: filter) {
                            filter = .all
                        }
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refreshInbox()
            }
            .onAppear {
                // Initialize with unread filter
                filter = .unread

                if viewModel.inboxLinks.isEmpty {
                    viewModel.loadInboxLinks()
                }
                viewModel.loadFavorites()
            }
        }
    }

    // MARK: - List Builder
    private var recipeListCondensed: some View {
        List {
            ForEach(filteredRecipeLinks) { link in
                SharedLinkCardCondensed(
                    link: link,
                    icloudID: viewModel.userID,
                    reactions: viewModel.reactionsByLink[link.id] ?? [],
                    replies: viewModel.repliesByLink[link.id] ?? [],
                    isRead: ReadLinkTracker.isLinkRead(linkID: link.id.recordName, userID: viewModel.userID),
                    isFavorited: viewModel.favoriteLinkIDs.contains(link.id),
                    showReadDot: true,
                    showSender: true,
                    onOpen: { viewModel.openLink(link) },
                    onFavoriteToggle: { viewModel.toggleFavorite(for: link) },
                    onReact: { emoji in viewModel.addReaction(to: link, emoji: emoji) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        viewModel.addReaction(to: link, emoji: "❤️")
                    } label: {
                        Label("Love", systemImage: "heart")
                    }
                    .tint(.pink)

                    Button {
                        activeReplyLinkID = link.id
                        inlineReplyDraft = ""
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    .tint(.blue)
                }
                .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                .onAppear {
                    // Trigger pagination when we hit the end of the filtered list
                    if link.id == filteredRecipeLinks.last?.id,
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
                LoadingRowRecipe()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Local Helpers (avoid name conflicts with InboxView.swift)
private struct RecipeEmptyState: View {
    let filter: LinkViewModel.InboxFilter
    let onViewAll: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                filter == .unread ? "No Unread Recipes" : "No Recipe Links",
                systemImage: "fork.knife"
            )
        } description: {
            Text(filter == .unread
                 ? "You've read all recipe links"
                 : "No recipe links have been shared with you yet")
        } actions: {
            Button("View All Recipes") { onViewAll() }
        }
    }
}

private struct LoadingRowRecipe: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    let previewID = "PREVIEW_USER_ID"
    return InboxRecipeView(
        viewModel: LinkViewModel(userID: previewID),
        tagEditingLink: .constant(nil)
    )
}
