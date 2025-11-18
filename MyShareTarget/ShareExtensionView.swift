//  ShareExtensionView.swift
//  MyShareTarget
//
//  Updated 2025-05-12 to read friend cache via ProfileCache

import SwiftUI
import LinkPresentation
import CloudKit

/// Displays the Share Extension UI, sourcing all user data from App Group defaults via ProfileCache
struct ShareExtensionView: View {
    // MARK: - Cached Current User Info
    @AppStorage("evensharely_icloudID", store: UserDefaults(suiteName: "group.com.marcsebes.evensharely"))
    private var appleUserID: String = ""

    @AppStorage("evensharely_fullName", store: UserDefaults(suiteName: "group.com.marcsebes.evensharely"))
    private var appleFullName: String = ""

    // MARK: - Friend Cache
    @State private var allUsers: [CachedUser] = []                // loaded from ProfileCache
    @State private var selectedRecipients: Set<String> = []      // set of appleUserID strings

    // MARK: - Share Data
    let sharedURL: URL
    var onComplete: () -> Void
    @State private var tagInput: String = ""
    @State private var selectedFilterTag: filterTag = .social
    @State private var linkMetadata: LPLinkMetadata?

    // MARK: - App Group UserDefaults
    private let defaults = UserDefaults(suiteName: "group.com.marcsebes.evensharely")
    private let lastRecipientsKey = "evensharely_lastRecipients"

    //MARK: - Show PopUp Alert Message
    @State private var showAlert = false
    
    
    init(sharedURL: URL, onComplete: @escaping () -> Void) {
        self.sharedURL = sharedURL
        self.onComplete = onComplete
        NSLog("[EXTLOG]: ShareExtensionView initialized with URL: %{public}@", sharedURL.absoluteString)
    }

    // MARK: - Load Cache
    private func loadCachedUsers() {
        let cached = ProfileCache.load()
        NSLog("[EXTLOG] ▶️ Cached users IDs: \(cached.map(\.id))")
        if cached.isEmpty {
            NSLog("[EXTLOG]: No cached users found")
        } else {
            NSLog("[EXTLOG]: Loaded \(cached.count) users from cache")
        }
        allUsers = cached

        if let saved = defaults?.array(forKey: lastRecipientsKey) as? [String] {
            selectedRecipients = Set(saved)
            NSLog("[EXTLOG]: Pre-selected last recipients: \(selectedRecipients)")
        }
    }

    // MARK: - Fetch Link Metadata
    private func fetchMetadata(for url: URL) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let metadata = metadata {
                DispatchQueue.main.async { linkMetadata = metadata }
            } else if let error = error {
                NSLog("[EXTLOG]: ❌ Failed to fetch metadata: %{public}@", error.localizedDescription)
            }
        }
    }

    // MARK: - Share Action
    private func share() {
        NSLog("[EXTLOG]: 🔥 Share Button Pressed...")
        guard !appleUserID.isEmpty else {
            NSLog("[EXTLOG]: ❌ Aborting share: appleUserID not loaded yet")
            return
        }

        var tags = tagInput
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        tags.append(selectedFilterTag.rawValue)
            

        let recipients = allUsers
            .filter { selectedRecipients.contains($0.id) }
            .map { $0.id }

        NSLog("[EXTLOG] ▶️ Sharing to recipients: \(recipients)")
        let sharedLink = SharedLink(
            id: CKRecord.ID(recordName: UUID().uuidString),
            url: sharedURL,
            senderIcloudID: appleUserID,
            senderFullName: appleFullName,
            recipientIcloudIDs: recipients,
            tags: tags,
            date: Date()
        )
        NSLog("[EXTLOG]: About to save SharedLink with senderFullName = %{public}@", appleFullName)

        CloudKitManager.shared.saveSharedLink(sharedLink) { result in
            switch result {
            case .success:
                defaults?.set(Array(selectedRecipients), forKey: lastRecipientsKey)
                NSLog("[EXTLOG]: ✅ SharedLink saved to CloudKit successfully")
            case .failure(let error):
                NSLog("[EXTLOG]: ❌ Failed to save SharedLink: %{public}@", error.localizedDescription)
            }
            onComplete()
        }
    }

    // MARK: - View Body
    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 20) {

                    // Link Preview
                    Text("Preview").font(.headline)
                    VStack {
                        if let metadata = linkMetadata {
                            LinkItemView(link: metadata.url?.absoluteString ?? "")
                        }
                    }
                    .frame(height:100)

                    // Tags Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags").font(.headline)
//                        TextField("e.g. funny, food, inspo", text: $tagInput)
//                            .textFieldStyle(.roundedBorder)
                        Picker("Link Type", selection: $selectedFilterTag) {
                                               ForEach(filterTag.allCases) { filterTag in
                                                   Text(filterTag.rawValue.capitalized)
                                                       .tag(filterTag)
                                               }
                                           }.pickerStyle(.segmented)
                        
                    }

                    // Recipients List
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recipients").font(.headline)
                        if allUsers.isEmpty {
                            Text("To begin sharing, add friends in the app!")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            List{
                                ForEach(allUsers, id: \ .id) { user in
                                    Button {
                                        if selectedRecipients.contains(user.id) {
                                            selectedRecipients.remove(user.id)
                                        } else {
                                            selectedRecipients.insert(user.id)
                                        }
                                    } label: {
                                        HStack {
                                            Text(user.fullName.isEmpty ? user.id : user.fullName)
                                            Spacer()
                                            if selectedRecipients.contains(user.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color("IconBackground"))
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(Color(Color.primary.opacity(0.1)))
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                        // Action Buttons
                        VStack(spacing: 12) {
                            if !selectedRecipients.isEmpty {
                                Button(action: share) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send").fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            else {
                                Button(action: {
                                    showAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send").fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundStyle(Color.black.opacity(0.2))
                                    .cornerRadius(12)
                                    
                                }
                                .alert("SquirrelBear", isPresented: $showAlert) {
                                    Button("OK", role: .cancel) {
                                        // Optional: Add any code to run when the button is tapped
                                    }
                                }
                                message: {
                                    Text("You Must Select at Least One Recipient Before Sharing.")
                                }

                            }
                           
                            Button("Cancel", role: .cancel) {
                                NSLog("[EXTLOG]: ⚪ Cancel tapped")
                                onComplete()
                            }
                            .foregroundColor(.secondary)
                        }
                       
                    }

                }
                .padding()
            }
            .navigationTitle("Share with SquirrelBear")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadCachedUsers()
            fetchMetadata(for: sharedURL)
        }
    }

}

