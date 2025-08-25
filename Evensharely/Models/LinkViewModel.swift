//
//  LinkViewModel.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//
import SwiftUI
import CloudKit
import Combine

class LinkViewModel: ObservableObject {
    @Published var inboxLinks: [SharedLink] = []
    @Published var sentLinks: [SharedLink] = []
    @Published var favoriteLinks: [SharedLink] = []
    @Published var favoriteLinkIDs: Set<CKRecord.ID> = []
    @Published var reactionsByLink: [CKRecord.ID: [Reaction]] = [:]
    
    @Published var isLoadingInbox = false
    @Published var isLoadingSent = false
    @Published var isLoadingFavorites = false
    
    @Published var allInboxLinksLoaded = false
    @Published var allSentLinksLoaded = false
    
    // Filter state
    @Published var inboxFilter: InboxFilter = .unread
    
    private var loadedInboxPages: Int = 0
    private var loadedSentPages: Int = 0
    private let daysPerPage = 30  // 30 days per page
    
    // Track oldest date we've loaded to prevent unnecessary queries
    private var oldestLoadedDate: Date?
    // Sentinel date representing the earliest possible date we care about
    private let earliestConsideredDate = Date(timeIntervalSince1970: 0) // Jan 1, 1970
    
    private let reactionManager = ReactionManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Add tasks for cancellation
    private var loadInboxTask: Task<Void, Never>?
    private var loadSentTask: Task<Void, Never>?
    private var loadFavoritesTask: Task<Void, Never>?
    private var loadReactionsTask: Task<Void, Never>?
    
    var userID: String {
        didSet {
            if oldValue != userID {
                // ID changed (e.g. login/logout), reload everything
                resetAll()
            }
        }
    }
    
    init(userID: String) {
        self.userID = userID
        
        // Load cached links
        inboxLinks = SharedLinkCache.load()
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Automatically update badge count when unread links change
        // FIXED: Properly handle weak self to prevent retain cycles
        $inboxLinks
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] links in
                guard let self = self else { return }
                BadgeManager.updateBadgeCount(for: links, userID: self.userID)
            }
            .store(in: &cancellables)
    }
    
    // FIXED: Add deinit to ensure cleanup
    deinit {
        // Cancel all ongoing tasks
        loadInboxTask?.cancel()
        loadSentTask?.cancel()
        loadFavoritesTask?.cancel()
        loadReactionsTask?.cancel()
        
        // Cancel all Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        print("✅ LinkViewModel deallocated properly")
    }
    
    // MARK: - Link Filters
    
    enum InboxFilter: String, CaseIterable, Identifiable {
        case unread = "Unread"
        case all = "All"
        
        var id: String { self.rawValue }
    }
    
    var filteredInboxLinks: [SharedLink] {
        switch inboxFilter {
        case .unread:
            return inboxLinks.filter { !ReadLinkTracker.isLinkRead(linkID: $0.id.recordName, userID: userID) }
                            .sorted(by: { $0.date > $1.date })
        case .all:
            return inboxLinks.sorted(by: { $0.date > $1.date })
        }
    }
    
    // MARK: - Reset Methods
    
    private func resetAll() {
        // Cancel any ongoing operations
        loadInboxTask?.cancel()
        loadSentTask?.cancel()
        loadFavoritesTask?.cancel()
        loadReactionsTask?.cancel()
        
        resetInboxPagination()
        resetSentPagination()
        inboxLinks = []
        sentLinks = []
        favoriteLinks = []
        favoriteLinkIDs = []
    }
    
    func resetInboxPagination() {
        loadedInboxPages = 0
        allInboxLinksLoaded = false
        oldestLoadedDate = nil
    }
    
    func resetSentPagination() {
        loadedSentPages = 0
        allSentLinksLoaded = false
    }
    
    // MARK: - Refresh Methods
    
    func refreshInbox() {
        loadInboxTask?.cancel()
        resetInboxPagination()
        loadFavorites()
        loadInboxLinks()
    }
    
    func refreshSent() {
        loadSentTask?.cancel()
        resetSentPagination()
        loadSentLinks()
    }
    
    // MARK: - Inbox Links
    
    func loadInboxLinks() {
        guard !isLoadingInbox, !allInboxLinksLoaded else { return }
        isLoadingInbox = true
        
        let currentPage = loadedInboxPages
        let calendar = Calendar.current
        let now = Date()
        
        let startOffset = -((currentPage + 1) * daysPerPage - 1)
        let endOffset = -(currentPage * daysPerPage)
        
        guard let startDate = calendar.date(byAdding: .day, value: startOffset, to: now),
              let endDate = calendar.date(byAdding: .day, value: endOffset, to: now) else {
            isLoadingInbox = false
            return
        }
        
        // Skip if we've already loaded links older than this start date
        if let oldestDate = oldestLoadedDate, startDate > oldestDate {
            print("🔄 Skipping fetch - already loaded links older than \(formattedDate(startDate))")
            isLoadingInbox = false
            loadedInboxPages += 1
            loadInboxLinks() // Continue to next page
            return
        }
        
        // If we've gone back further than we care about, stop loading
        if startDate < earliestConsideredDate {
            print("🛑 Reached earliest considered date, stopping pagination")
            isLoadingInbox = false
            allInboxLinksLoaded = true
            return
        }
        
        print("🗓️ Fetching inbox from \(formattedDate(startDate)) to \(formattedDate(endDate))")
        
        // FIXED: Use weak self in all closures to prevent retain cycles
        CloudKitManager.shared.fetchSharedLinks(from: startDate, to: endDate) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoadingInbox = false
                
                switch result {
                case .success(let fetched):
                    // Filter out links we already have
                    let newLinks = fetched.filter { newLink in
                        !self.inboxLinks.contains(where: { $0.id.recordName == newLink.id.recordName })
                    }
                    
                    // Update the oldest loaded date if we got any links
                    if let oldestFetchedLink = fetched.min(by: { $0.date < $1.date }) {
                        if let currentOldest = self.oldestLoadedDate {
                            self.oldestLoadedDate = min(currentOldest, oldestFetchedLink.date)
                        } else {
                            self.oldestLoadedDate = oldestFetchedLink.date
                        }
                    }
                    
                    self.loadedInboxPages += 1
                    
                    // If we got no new links AND we've made several attempts OR
                    // we've gone back far enough, stop pagination
                    if newLinks.isEmpty {
                        let farEnoughBack = startDate < Date(timeIntervalSinceNow: -180*24*60*60) // 180 days
                        let madeEnoughAttempts = self.loadedInboxPages > 6
                        
                        if farEnoughBack || madeEnoughAttempts {
                            print("📊 Stopping pagination: farEnoughBack=\(farEnoughBack), madeEnoughAttempts=\(madeEnoughAttempts)")
                            self.allInboxLinksLoaded = true
                            return
                        }
                        
                        // Otherwise try the next page
                        self.loadInboxLinks()
                        return
                    }
                    
                    // Add new links
                    self.inboxLinks.append(contentsOf: newLinks)
                    
                    // Sort links by date (newest first)
                    self.inboxLinks.sort(by: { $0.date > $1.date })
                    
                    // Save to cache
                    SharedLinkCache.save(self.inboxLinks)
                    
                    // Load reactions for new links
                    self.loadReactionsForLinks(newLinks)
                    
                    // Update badge count
                    BadgeManager.updateBadgeCount(for: self.inboxLinks, userID: self.userID)
                    
                case .failure(let error):
                    print("❌ Failed to fetch inbox: \(error.localizedDescription)")
                    // Still increment the page counter to avoid getting stuck
                    self.loadedInboxPages += 1
                    
                    // Set all loaded after several failed attempts
                    if self.loadedInboxPages > 3 {
                        self.allInboxLinksLoaded = true
                    }
                }
            }
        }
    }
    
    // MARK: - Sent Links
    
    func loadSentLinks() {
        guard !isLoadingSent else { return }
        isLoadingSent = true
        
        let calendar = Calendar.current
        let now = Date()
        
        // Load sent links from the past year
        guard let startDate = calendar.date(byAdding: .year, value: -1, to: now) else {
            isLoadingSent = false
            return
        }
        
        // Cancel any existing task
        loadSentTask?.cancel()
        
        // Create new task with cancellation support
        loadSentTask = Task { [weak self] in
            guard let self = self else { return }
            
            // FIXED: Use weak self in CloudKit callbacks
            CloudKitManager.shared.fetchSentLinks(for: self.userID, fromDate: startDate, toDate: now) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoadingSent = false
                    self.allSentLinksLoaded = true // Only load once for sent links
                    
                    switch result {
                    case .success(let fetched):
                        self.sentLinks = fetched.sorted(by: { $0.date > $1.date })
                        
                        // Load reactions for sent links
                        self.loadReactionsForLinks(fetched)
                        
                    case .failure(let error):
                        print("❌ Failed to fetch sent links: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Favorites
    
    func loadFavorites() {
        isLoadingFavorites = true
        
        // Cancel any existing task
        loadFavoritesTask?.cancel()
        
        loadFavoritesTask = Task { [weak self] in
            guard let self = self else { return }
            
            // FIXED: Use weak self in callbacks
            loadFavoritedLinks(userIcloudID: self.userID) { [weak self] fetchedLinks in
                guard let self = self else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.favoriteLinks = fetchedLinks.sorted(by: { $0.date > $1.date })
                    self.favoriteLinkIDs = Set(fetchedLinks.map { $0.id })
                    self.isLoadingFavorites = false
                }
            }
        }
    }
    
    // MARK: - Link Actions
    
    func toggleFavorite(for link: SharedLink) {
        let privateDB = CloudKitConfig.container.privateCloudDatabase
        let linkReference = CKRecord.Reference(recordID: link.id, action: .none)
        
        if favoriteLinkIDs.contains(link.id) {
            // Remove from favorites
            let predicate = NSPredicate(format: "userIcloudID == %@ AND linkReference == %@", userID, linkReference)
            let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)
            
            // FIXED: Use weak self in database operations
            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .failure(let error):
                    print("❌ Failed to query for FavoriteLink to delete: \(error)")
                case .success(let (matchResults, _)):
                    if let recordID = matchResults.first?.0 {
                        privateDB.delete(withRecordID: recordID) { [weak self] _, error in
                            guard let self = self else { return }
                            if let error = error {
                                print("❌ Error deleting FavoriteLink: \(error)")
                            } else {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    self.favoriteLinkIDs.remove(link.id)
                                    self.favoriteLinks.removeAll { $0.id == link.id }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Add to favorites
            let favorite = FavoriteLink(userIcloudID: userID, linkReference: linkReference)
            let record = favorite.toRecord()
            
            privateDB.save(record) { [weak self] _, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error saving FavoriteLink: \(error)")
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.favoriteLinkIDs.insert(link.id)
                        
                        // Find link in inbox or sent and add to favorites
                        if let link = self.inboxLinks.first(where: { $0.id == link.id }) ??
                                      self.sentLinks.first(where: { $0.id == link.id }) {
                            self.favoriteLinks.append(link)
                            self.favoriteLinks.sort(by: { $0.date > $1.date })
                        }
                    }
                }
            }
        }
    }
    
    func openLink(_ link: SharedLink) {
        UIApplication.shared.open(link.url)
        ReadLinkTracker.markAsRead(linkID: link.id.recordName, userID: userID)
        BadgeManager.updateBadgeCount(for: inboxLinks, userID: userID)
    }
    
    func addReaction(to link: SharedLink, emoji: String) {
        // Cancel any existing reaction task
        loadReactionsTask?.cancel()
        
        loadReactionsTask = Task { [weak self] in
            guard let self = self else { return }
            try? await self.reactionManager.addOrUpdateReaction(linkID: link.id, userID: self.userID, reactionType: emoji)
            self.loadReactions(for: link)
        }
    }
    
    func loadReactions(for link: SharedLink) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let reactions = try await self.reactionManager.fetchReactions(for: link.id)
                DispatchQueue.main.async { [weak self] in
                    self?.reactionsByLink[link.id] = reactions
                }
            } catch {
                print("⚠️ Failed to fetch reactions: \(error)")
            }
        }
    }
    
    // FIXED: New method to load reactions with proper memory management
    private func loadReactionsForLinks(_ links: [SharedLink]) {
        Task { [weak self] in
            guard let self = self else { return }
            let reactionMap = await self.reactionManager.loadAllReactions(
                for: links.map { $0.id },
                userID: self.userID
            )
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for (key, value) in reactionMap {
                    self.reactionsByLink[key] = value
                }
            }
        }
    }
    
    func deleteLink(_ link: SharedLink) {
        CloudKitManager.shared.deleteSharedLink(link) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.inboxLinks.removeAll { $0.id == link.id }
                    self.sentLinks.removeAll { $0.id == link.id }
                    self.favoriteLinks.removeAll { $0.id == link.id }
                    self.favoriteLinkIDs.remove(link.id)
                    SharedLinkCache.save(self.inboxLinks)
                case .failure(let error):
                    print("❌ Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateTags(_ tags: [String], for link: SharedLink) {
        CloudKitManager.shared.updateSharedLinkTags(recordID: link.id, tags: tags) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success:
                    // Update tags in all lists that might contain this link
                    if let idx = self.inboxLinks.firstIndex(where: { $0.id == link.id }) {
                        self.inboxLinks[idx].tags = tags
                    }
                    if let idx = self.sentLinks.firstIndex(where: { $0.id == link.id }) {
                        self.sentLinks[idx].tags = tags
                    }
                    if let idx = self.favoriteLinks.firstIndex(where: { $0.id == link.id }) {
                        self.favoriteLinks[idx].tags = tags
                    }
                    SharedLinkCache.save(self.inboxLinks)
                case .failure(let error):
                    print("❌ Tag save failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
