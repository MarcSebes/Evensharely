//
//  LinkViewModel.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//  Enhanced with improved pagination logic
//
import SwiftUI
import CloudKit
import Combine

@MainActor
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
    
    // Enhanced error handling
    @Published var lastError: Error?
    @Published var hasConnectionError = false
    
    // Filter state
    @Published var inboxFilter: InboxFilter = .unread
    
    // MARK: - Configuration Constants
    private struct PaginationConfig {
        static let daysPerPage = 30
        static let maxRetryAttempts = 6
        static let maxLookbackDays = 180
        static let minLinksThreshold = 5 // Minimum links needed before stopping pagination
        static let batchSize = 50 // CloudKit query limit
    }
    
    // MARK: - Pagination State
    private var loadedInboxPages: Int = 0
    private var loadedSentPages: Int = 0
    private var oldestLoadedDate: Date?
    private var newestLoadedDate: Date?
    private var consecutiveEmptyPages = 0
    
    // Sentinel date representing the earliest possible date we care about
    private let earliestConsideredDate = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(timeIntervalSince1970: 0)
    
    private let reactionManager = ReactionManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Enhanced task management
    private var loadInboxTask: Task<Void, Never>?
    private var loadSentTask: Task<Void, Never>?
    private var loadFavoritesTask: Task<Void, Never>?
    private var loadReactionsTask: Task<Void, Never>?
    
    // Concurrent access protection
    private let inboxQueue = DispatchQueue(label: "inbox.pagination", qos: .userInitiated)
    private var isCurrentlyFetching = false
    
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
        updateDateBounds()
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Automatically update badge count when unread links change
        $inboxLinks
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] links in
                guard let self = self else { return }
                BadgeManager.updateBadgeCount(for: links, userID: self.userID)
            }
            .store(in: &cancellables)
        
        // Clear errors after successful loads
        $inboxLinks
            .sink { [weak self] _ in
                self?.clearErrors()
            }
            .store(in: &cancellables)
    }
    
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
        case .all:
            return inboxLinks
        }
    }
    
    // MARK: - Enhanced Reset Methods
    
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
        reactionsByLink = [:]
        clearErrors()
    }
    
    func resetInboxPagination() {
        inboxQueue.sync {
            loadedInboxPages = 0
            allInboxLinksLoaded = false
            oldestLoadedDate = nil
            newestLoadedDate = nil
            consecutiveEmptyPages = 0
            isCurrentlyFetching = false
        }
    }
    
    func resetSentPagination() {
        loadedSentPages = 0
        allSentLinksLoaded = false
    }
    
    private func clearErrors() {
        lastError = nil
        hasConnectionError = false
    }
    
    // MARK: - Enhanced Date Bounds Tracking
    
    private func updateDateBounds() {
        guard !inboxLinks.isEmpty else { return }
        
        let dates = inboxLinks.map { $0.date }
        oldestLoadedDate = dates.min()
        newestLoadedDate = dates.max()
    }
    
    // MARK: - Refresh Methods
    
    func refreshInbox() {
        loadInboxTask?.cancel()
        resetInboxPagination()
        inboxLinks = [] // Clear existing data for fresh start
        loadFavorites()
        loadInboxLinks()
    }
    
    func refreshSent() {
        loadSentTask?.cancel()
        resetSentPagination()
        sentLinks = []
        loadSentLinks()
    }
    
    // MARK: - Enhanced Inbox Links Loading
    
    func loadInboxLinks() {
        // Prevent concurrent fetching
        inboxQueue.sync {
            guard !isCurrentlyFetching else {
                print("🔄 Already fetching inbox links, skipping...")
                return
            }
            
            guard !isLoadingInbox, !allInboxLinksLoaded else {
                print("📊 Inbox loading blocked: isLoading=\(isLoadingInbox), allLoaded=\(allInboxLinksLoaded)")
                return
            }
            
            isCurrentlyFetching = true
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoadingInbox = true
        }
        
        let currentPage = loadedInboxPages
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate date range for this page
        let startOffset = -((currentPage + 1) * PaginationConfig.daysPerPage - 1)
        let endOffset = -(currentPage * PaginationConfig.daysPerPage)
        
        guard let startDate = calendar.date(byAdding: .day, value: startOffset, to: now),
              let endDate = calendar.date(byAdding: .day, value: endOffset, to: now) else {
            finishInboxLoading(success: false, error: nil)
            return
        }
        
        // Enhanced bounds checking
        if shouldSkipFetch(startDate: startDate, endDate: endDate) {
            finishInboxLoading(success: true, error: nil)
            continueToNextPage()
            return
        }
        
        // Check if we've gone too far back
        if shouldStopPagination(startDate: startDate) {
            finishInboxLoading(success: true, error: nil, allLoaded: true)
            return
        }
        
        print("🗓️ Fetching inbox page \(currentPage + 1) from \(formattedDate(startDate)) to \(formattedDate(endDate))")
        
        // Cancel any existing task
        loadInboxTask?.cancel()
        
        loadInboxTask = Task { [weak self] in
            await self?.performInboxFetch(startDate: startDate, endDate: endDate, currentPage: currentPage)
            return // Explicit return for Void
        }
    }
    
    private func shouldSkipFetch(startDate: Date, endDate: Date) -> Bool {
        // Skip if we've already loaded links older than this start date
        if let oldestDate = oldestLoadedDate, startDate > oldestDate {
            print("🔄 Skipping fetch - already loaded links older than \(formattedDate(startDate))")
            return true
        }
        
        // Skip if this date range is newer than our newest loaded date (shouldn't happen in normal pagination)
        if let newestDate = newestLoadedDate, endDate > newestDate && loadedInboxPages > 0 {
            print("⚠️ Skipping fetch - date range is newer than loaded data")
            return true
        }
        
        return false
    }
    
    private func shouldStopPagination(startDate: Date) -> Bool {
        // Stop if we've gone back further than we care about
        if startDate < earliestConsideredDate {
            print("🛑 Reached earliest considered date (\(formattedDate(earliestConsideredDate))), stopping pagination")
            return true
        }
        
        // Stop if we've made too many attempts without finding links
        if consecutiveEmptyPages >= 3 && loadedInboxPages > PaginationConfig.maxRetryAttempts {
            print("🛑 Too many empty pages (\(consecutiveEmptyPages)) after \(loadedInboxPages) attempts, stopping")
            return true
        }
        
        return false
    }
    
    private func performInboxFetch(startDate: Date, endDate: Date, currentPage: Int) async {
        do {
            // FIXED: Use the existing private async method instead of creating duplicate
            let fetched: [SharedLink] = try await withCheckedThrowingContinuation { continuation in
                CloudKitManager.shared.fetchSharedLinks(from: startDate, to: endDate) { result in
                    switch result {
                    case .success(let links):
                        continuation.resume(returning: links)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            await MainActor.run { [weak self] in
                self?.processInboxFetchResult(fetched, currentPage: currentPage, startDate: startDate)
            }
            
        } catch {
            await MainActor.run { [weak self] in
                self?.handleInboxFetchError(error, currentPage: currentPage)
            }
        }
    }
    
    private func processInboxFetchResult(_ fetched: [SharedLink], currentPage: Int, startDate: Date) {
        guard currentPage == loadedInboxPages else {
            print("⚠️ Page mismatch: expected \(loadedInboxPages), got \(currentPage). Ignoring stale result.")
            finishInboxLoading(success: false, error: nil)
            return
        }
        
        // Filter out links we already have (more efficient set-based lookup)
        let existingIDs = Set(inboxLinks.map { $0.id.recordName })
        let newLinks = fetched.filter { !existingIDs.contains($0.id.recordName) }
        
        print("📦 Fetched \(fetched.count) total, \(newLinks.count) new links for page \(currentPage + 1)")
        
        // Update pagination state
        loadedInboxPages += 1
        
        // Update date bounds
        updateDateBoundsAfterFetch(fetched)
        
        // Handle empty results
        if newLinks.isEmpty {
            consecutiveEmptyPages += 1
            let shouldStop = shouldStopAfterEmptyPage(startDate: startDate)
            finishInboxLoading(success: true, error: nil, allLoaded: shouldStop)
            
            if !shouldStop {
                continueToNextPage()
            }
            return
        }
        
        // Reset empty page counter on successful fetch
        consecutiveEmptyPages = 0
        
        // Add new links efficiently
        appendNewLinks(newLinks)
        
        // Save to cache (async to avoid blocking)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            SharedLinkCache.save(self.inboxLinks)
        }
        
        // Load reactions for new links
        loadReactionsForLinks(newLinks)
        
        finishInboxLoading(success: true, error: nil)
    }
    
    private func updateDateBoundsAfterFetch(_ fetchedLinks: [SharedLink]) {
        guard !fetchedLinks.isEmpty else { return }
        
        let fetchedDates = fetchedLinks.map { $0.date }
        let minFetched = fetchedDates.min()!
        let maxFetched = fetchedDates.max()!
        
        oldestLoadedDate = oldestLoadedDate.map { min($0, minFetched) } ?? minFetched
        newestLoadedDate = newestLoadedDate.map { max($0, maxFetched) } ?? maxFetched
    }
    
    private func shouldStopAfterEmptyPage(startDate: Date) -> Bool {
        let farEnoughBack = startDate < Date(timeIntervalSinceNow: -TimeInterval(PaginationConfig.maxLookbackDays * 24 * 60 * 60))
        let madeEnoughAttempts = loadedInboxPages > PaginationConfig.maxRetryAttempts
        let tooManyEmptyPages = consecutiveEmptyPages >= 3
        
        if farEnoughBack || madeEnoughAttempts || tooManyEmptyPages {
            print("📊 Stopping pagination: farBack=\(farEnoughBack), attempts=\(madeEnoughAttempts), empty=\(tooManyEmptyPages)")
            return true
        }
        
        return false
    }
    
    private func appendNewLinks(_ newLinks: [SharedLink]) {
        // Insert new links maintaining sort order (newest first)
        inboxLinks.append(contentsOf: newLinks)
        inboxLinks.sort { $0.date > $1.date }
        
        // Alternative: More efficient insertion for already-sorted data
        // This could be optimized further with binary search insertion
    }
    
    private func continueToNextPage() {
        // Continue to next page after a brief delay to avoid overwhelming the system
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            self?.loadInboxLinks()
        }
    }
    
    private func handleInboxFetchError(_ error: Error, currentPage: Int) {
        print("❌ Failed to fetch inbox page \(currentPage + 1): \(error.localizedDescription)")
        
        lastError = error
        
        // Check if it's a network error
        if let nsError = error as NSError?,
           nsError.code == NSURLErrorNotConnectedToInternet {
            hasConnectionError = true
        }
        
        // Still increment the page counter to avoid getting stuck
        loadedInboxPages += 1
        
        // Set all loaded after several failed attempts
        let shouldStop = loadedInboxPages > 3
        finishInboxLoading(success: false, error: error, allLoaded: shouldStop)
    }
    
    private func finishInboxLoading(success: Bool, error: Error?, allLoaded: Bool = false) {
        inboxQueue.sync {
            isCurrentlyFetching = false
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoadingInbox = false
            if allLoaded {
                self?.allInboxLinksLoaded = true
            }
            if let error = error {
                self?.lastError = error
            }
        }
    }
    
    // MARK: - Task Cancellation Helper (removed as it was causing issues)
    
    // MARK: - Sent Links (unchanged)
    
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
        
        loadSentTask = Task { [weak self] in
            guard let self = self else { return }
            
            CloudKitManager.shared.fetchSentLinks(for: self.userID, fromDate: startDate, toDate: now) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoadingSent = false
                    self.allSentLinksLoaded = true
                    
                    switch result {
                    case .success(let fetched):
                        self.sentLinks = fetched.sorted(by: { $0.date > $1.date })
                        self.loadReactionsForLinks(fetched)
                        
                    case .failure(let error):
                        print("❌ Failed to fetch sent links: \(error.localizedDescription)")
                        self.lastError = error
                    }
                }
            }
        }
    }
    
    // MARK: - Favorites (unchanged)
    
    func loadFavorites() {
        isLoadingFavorites = true
        
        loadFavoritesTask?.cancel()
        
        loadFavoritesTask = Task { [weak self] in
            guard let self = self else { return }
            
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
    
    // MARK: - Link Actions (unchanged but with better error handling)
    
    func toggleFavorite(for link: SharedLink) {
        let privateDB = CloudKitConfig.container.privateCloudDatabase
        let linkReference = CKRecord.Reference(recordID: link.id, action: .none)
        
        if favoriteLinkIDs.contains(link.id) {
            // Remove from favorites
            let predicate = NSPredicate(format: "userIcloudID == %@ AND linkReference == %@", userID, linkReference)
            let query = CKQuery(recordType: "FavoriteLink", predicate: predicate)
            
            privateDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .failure(let error):
                    print("❌ Failed to query for FavoriteLink to delete: \(error)")
                    DispatchQueue.main.async {
                        self.lastError = error
                    }
                case .success(let (matchResults, _)):
                    if let recordID = matchResults.first?.0 {
                        privateDB.delete(withRecordID: recordID) { [weak self] _, error in
                            guard let self = self else { return }
                            if let error = error {
                                print("❌ Error deleting FavoriteLink: \(error)")
                                DispatchQueue.main.async {
                                    self.lastError = error
                                }
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
                    DispatchQueue.main.async {
                        self.lastError = error
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.favoriteLinkIDs.insert(link.id)
                        
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
        loadReactionsTask?.cancel()
        
        loadReactionsTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                try await self.reactionManager.addOrUpdateReaction(linkID: link.id, userID: self.userID, reactionType: emoji)
                await self.loadReactions(for: link)
            } catch {
                self.lastError = error
            }
        }
    }
    
    func loadReactions(for link: SharedLink) async {
        do {
            let reactions = try await reactionManager.fetchReactions(for: link.id)
            await MainActor.run { [weak self] in
                self?.reactionsByLink[link.id] = reactions
            }
        } catch {
            print("⚠️ Failed to fetch reactions: \(error)")
            await MainActor.run { [weak self] in
                self?.lastError = error
            }
        }
    }
    
    private func loadReactionsForLinks(_ links: [SharedLink]) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let reactionMap = await self.reactionManager.loadAllReactions(
                for: links.map { $0.id },
                userID: self.userID
            )
            
            for (key, value) in reactionMap {
                self.reactionsByLink[key] = value
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
                    self.lastError = error
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
                    self.lastError = error
                }
            }
        }
    }
    
    // MARK: - Public Pagination Status
    
    var paginationStatus: String {
        if allInboxLinksLoaded {
            return "All links loaded (\(inboxLinks.count) total)"
        } else if isLoadingInbox {
            return "Loading page \(loadedInboxPages + 1)..."
        } else {
            return "Loaded \(inboxLinks.count) links in \(loadedInboxPages) pages"
        }
    }
    
    var canLoadMore: Bool {
        return !isLoadingInbox && !allInboxLinksLoaded
    }
}


