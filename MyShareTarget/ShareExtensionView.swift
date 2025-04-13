//
//  ShareExtensionView.swift
//  MyShareTarget
//
//  Created by Marc Sebes on 4/7/25.
//

import SwiftUI
import CloudKit
import LinkPresentation



struct ShareExtensionView: View {
    @State private var allUsers: [UserProfile] = []
    @State private var selectedRecipients: Set<String> = []
    @State private var currentUserIcloudID: String = ""
    @State private var linkMetadata: LPLinkMetadata?
    @State private var currentUserFullName: String = ""
    private let lastRecipientsKey = "evensharely_lastRecipients"
    
    let sharedURL: URL
    var onComplete: () -> Void

    @State private var tagInput: String = ""
    @State private var recipientsInput: String = ""

    init(sharedURL: URL, onComplete: @escaping () -> Void) {
        self.sharedURL = sharedURL
        self.onComplete = onComplete
        print("🧪 ShareExtensionView initialized with URL: \(sharedURL)")
    }
    func fetchMetadata(for url: URL) {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            if let metadata = metadata {
                DispatchQueue.main.async {
                    self.linkMetadata = metadata
                }
            } else if let error = error {
                print("❌ Failed to fetch metadata: \(error.localizedDescription)")
            }
        }
    }
    
    func logToFile(_ text: String) {
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.marcsebes.evensharely") {
            let fileURL = dir.appendingPathComponent("debug-log.txt")
            let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            try? (existing + "\n" + text).write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    func loadUsers() {
        print("📡 loadUsers() called")

        CloudKitManager.shared.fetchAllUserProfiles { result in
            switch result {
            case .success(let users):
                logToFile("✅ Loaded \(users.count) users")
                self.allUsers = users

                // Pre-select last shared recipients
                if let saved = UserDefaults.standard.array(forKey: lastRecipientsKey) as? [String] {
                    let matching = users.filter { saved.contains($0.username) }
                    self.selectedRecipients = Set(matching.map(\.username))
                   logToFile("✅ Pre-selected last recipients: \(self.selectedRecipients)")
                }

            case .failure(let error):
                logToFile("❌ Failed to load users: \(error.localizedDescription)")
            }
        }
    }

    
    func share() {
        print("🟢 Send button tapped")
        guard !currentUserIcloudID.isEmpty else {
            print("❌ Aborting share: senderIcloudID not loaded yet")
            return
        }

        let tags = tagInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let selectedUsers = allUsers.filter { selectedRecipients.contains($0.username) }

        let sharedLink = SharedLink(
            id: CKRecord.ID(recordName: UUID().uuidString),
            url: sharedURL,
            senderIcloudID: currentUserIcloudID,
            senderFullName: currentUserFullName, 
            recipientIcloudIDs: selectedUsers.map(\.icloudID),
            tags: tags,
            date: Date()
        )


        CloudKitManager.shared.saveSharedLink(sharedLink) { result in
            switch result {
            case .success:
                UserDefaults.standard.set(Array(selectedRecipients), forKey: lastRecipientsKey)
                print("✅ SharedLink saved to CloudKit successfully")
            case .failure(let error):
                print("❌ Failed to save SharedLink: \(error.localizedDescription)")
            }
            onComplete()
        }
    }


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Shared URL
                    VStack(alignment: .leading, spacing: 4) {
                        
                        if let metadata = linkMetadata {
                            Text("Preview")
                                .font(.headline)
                            LinkPreview(metadata: metadata)
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                        } else {
                            
                            Text("Shared URL")
                                .font(.headline)
                            Text(sharedURL.absoluteString)
                                .font(.callout)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .truncationMode(.middle)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    // Tags input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.headline)
                        TextField("e.g. funny, food, inspo", text: $tagInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Recipients
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recipients")
                            .font(.headline)

                        if allUsers.isEmpty {
                            Text("Loading users...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(allUsers, id: \.id) { user in
                                    Button(action: {
                                        if selectedRecipients.contains(user.username) {
                                            selectedRecipients.remove(user.username)
                                        } else {
                                            selectedRecipients.insert(user.username)
                                        }
                                    }) {
                                        HStack {
                                            Text(user.fullName.isEmpty ? user.username : user.fullName)
                                            Spacer()
                                            if selectedRecipients.contains(user.username) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                        }
                    }

                    // Share Button
                    Button(action: share) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(currentUserIcloudID.isEmpty || selectedRecipients.isEmpty)

                    // Cancel Button
                    Button("Cancel", role: .cancel) {
                        print("⚪ Cancel tapped")
                        onComplete()
                    }
                    .padding(.top, 8)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Share to Evensharely")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            print("🎯 onAppear reached")
            let containerID = CloudKitConfig.container.containerIdentifier ?? "Unknown"
            print("🧩 ShareExtension using container: \(containerID)")
            logToFile("🧩 ShareExtension using container: \(containerID)")

            loadUsers()
            fetchMetadata(for: sharedURL)
            
            CloudKitConfig.container.fetchUserRecordID { recordID, error in
                if let recordID = recordID {
                    DispatchQueue.main.async {
                        self.currentUserIcloudID = recordID.recordName
                        print("✅ currentUserIcloudID: \(self.currentUserIcloudID)")

                        // Fetch the full name for this user
                        CloudKitManager.shared.fetchUserProfile(forIcloudID: recordID.recordName) { result in
                            switch result {
                            case .success(let profile):
                                self.currentUserFullName = profile?.fullName ?? "Unknown"
                                print("👤 Loaded full name: \(self.currentUserFullName)")
                            case .failure(let error):
                                print("❌ Failed to fetch user profile: \(error.localizedDescription)")
                            }
                        }
                    }
                } else if let error = error {
                    print("❌ Failed to fetch iCloud ID: \(error.localizedDescription)")
                }
            }


        }
    }
}
