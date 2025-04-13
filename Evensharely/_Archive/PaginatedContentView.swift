//
//  PaginatedContentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//
/*
import SwiftUI
import CloudKit

struct PaginatedContentView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @StateObject private var viewModel = LinkFeedViewModel()
    @State private var favoriteLinkIDs: Set<CKRecord.ID> = []
    

    var body: some View {
        List {
            ForEach(viewModel.links) { link in
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
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    Button(action: {
                        UIApplication.shared.open(link.url)
                    }) {
                        LinkPreviewPlain(previewURL: link.url)
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())

                    HStack {
                        ForEach(["👍", "❤️", "😂", "😮"], id: \.self) { emoji in
                            let count = viewModel.reactionCount(for: link.id, emoji: emoji)
                            Text("\(emoji) \(count)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }
                .padding(.vertical, 4)
                .onAppear {
                    if link.id == viewModel.links.last?.id {
                        viewModel.loadMoreLinksIfNeeded()
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView("Loading more...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            viewModel.fetchInitialLinks()
        }
        .navigationTitle("Shared with Me")
    }
}

@MainActor
class LinkFeedViewModel: ObservableObject {
    @Published var links: [SharedLink] = []
    @Published var isLoading = false
    @Published var allLinksLoaded = false
    private var cursor: CKQueryOperation.Cursor?
    private var endDate = Date()
    private var emptyPageCount = 0
    private let maxEmptyPages = 3

    func fetchInitialLinks() {
    guard !isLoading else { return }
    isLoading = true
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    print("APP LOGGED: 📣 Running initial recipient-filtered fetch from \(formattedDate(startDate)) to \(formattedDate(endDate))")

    CloudKitManager.shared.fetchSharedLinks(from: startDate, to: endDate) { result in
        DispatchQueue.main.async {
            self.isLoading = false
            switch result {
            case .success(let fetched):
                let filtered = fetched.filter { newLink in
                    !self.links.contains(where: { $0.id == newLink.id })
                }
                self.links.append(contentsOf: filtered)

                if filtered.isEmpty {
                    self.emptyPageCount += 1
                    if self.emptyPageCount >= self.maxEmptyPages {
                        print("APP LOGGED: 🛑 No more links after \(self.emptyPageCount) empty pages. Stopping.")
                        self.allLinksLoaded = true
                    } else {
                        print("APP LOGGED: ⚠️ Empty page \(self.emptyPageCount)/\(self.maxEmptyPages). Will keep trying.")
                        self.loadOlderDateWindow()
                    }
                } else {
                    self.emptyPageCount = 0
                    self.loadOlderDateWindow()
                }
                print("APP LOGGED: ✅ Loaded \(filtered.count) filtered links from initial load")
            case .failure(let error):
                print("APP LOGGED: ❌ Initial fetch failed: \(error.localizedDescription)")
            }
        }
    }
    }

    func loadMoreLinksIfNeeded() {
        guard !isLoading, !allLinksLoaded else {
            print("APP LOGGED: 🔕 Skipping load — either already loading or reached end.")
            return
        }

        isLoading = true

        if let cursor = cursor {
            fetchLinks(cursor: cursor)
        } else {
            loadOlderDateWindow()
        }
    }


    func refresh() async {
        links = []
        cursor = nil
        endDate = Date()
        fetchInitialLinks()
    }

    private func fetchLinks(query: CKQuery? = nil, cursor: CKQueryOperation.Cursor? = nil) {
    var recordsAdded = 0

    if let cursor = cursor {
        let operation = CKQueryOperation(cursor: cursor)
        operation.resultsLimit = 20

        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                let dateString = (record["date"] as? Date).map { formattedDate($0) } ?? "unknown"
                print("APP LOGGED: 📥 Loaded link dated \(dateString)")
                DispatchQueue.main.async {
                    let link = SharedLink(record: record)
                    if !self.links.contains(where: { $0.id == link.id }) {
                        self.links.append(link)
                        recordsAdded += 1
                    }
                }
            case .failure(let error):
                print("APP LOGGED: ❌ Error fetching record: \(error.localizedDescription)")
            }
        }

        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        self.cursor = cursor
                        print("APP LOGGED: 📦 More links available")
                    } else {
                        self.cursor = nil
                        print("APP LOGGED: 🔁 No cursor. Will continue using date range pagination.")
                        self.loadOlderDateWindow()
                    }
                case .failure(let error):
                    print("APP LOGGED: ❌ Query failed: \(error.localizedDescription)")
                }
            }
        }

        CloudKitConfig.container.publicCloudDatabase.add(operation)

    } else {
        loadOlderDateWindow()
    }
}

    private func loadOlderDateWindow() {
        let previousEndDate = endDate
        endDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        print("APP LOGGED: Manually paginating: \(formattedDate(startDate)) → \(formattedDate(endDate))")

        CloudKitManager.shared.fetchSharedLinks(from: startDate, to: endDate) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let newLinks):
                    let filtered = newLinks.filter { newLink in
                        !self.links.contains(where: { $0.id == newLink.id })
                    }
                    self.links.append(contentsOf: filtered)
                    self.allLinksLoaded = filtered.isEmpty
                    print("APP LOGGED: 🧩 Added \(filtered.count) links from \(formattedDate(startDate)) → \(formattedDate(previousEndDate))")
                    
                    if !filtered.isEmpty {
                        // Automatically continue if we got results but no cursor (pure date paging)
                        self.loadOlderDateWindow()
                    }
                case .failure(let error):
                    print("APP LOGGED: ❌ Error fetching shared links: \(error.localizedDescription)")
                    self.allLinksLoaded = true
                }
            }
        }
    }

    func reactionCount(for linkID: CKRecord.ID, emoji: String) -> Int {
        // Replace this with real reaction tracking logic
        return Int.random(in: 0...5)
    }
}
*/
