//
//  UserProfileView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/17/25.
//  Updated to display email address
//
//
//  UserProfileView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/17/25.
//  Updated to display email address
//
import SwiftUI
import CloudKit

/// ViewModel for UserProfileView using MVVM
final class UserProfileViewModel: ObservableObject {
    // MARK: - Published properties for binding to SwiftUI
    @Published var fullName: String = ""
    @Published var selectedImage: UIImage?
    @Published var friendNamesText: String = "None"
    @Published var icloudID: String = ""
    @Published var email: String = ""    // NEW: store email
    @Published var appleUserID: String = ""
    @Published var name: String = ""
    
    // MARK: – Link stats
    @Published var sentCount: Int = 0
    @Published var receivedCount: Int = 0
    @Published var allLinks: [SharedLink] = []
    
    init(appleUserID: String = UserDefaults.standard.string(forKey: "evensharely_icloudID") ?? "") {
        self.appleUserID = appleUserID
        loadProfileAndFriends()
        loadLinkStats()
    }
    
    /// Loads critical stats about user
    private func loadLinkStats() {
        guard !appleUserID.isEmpty else { return }
        // Sent links
        CloudKitManager.shared.fetchSentLinks(for: appleUserID) { [weak self] result in
            switch result {
            case .success(let links):
                DispatchQueue.main.async { self?.sentCount = links.count }
            case .failure(let error):
                print("❌ Error fetching sent links: \(error)")
            }
        }
        // Received links
        CloudKitManager.shared.fetchSharedLinks { [weak self] result in
            switch result {
            case .success(let links):
                DispatchQueue.main.async {
                    self?.receivedCount = links.count
                    self?.allLinks = links
                }
            case .failure(let error):
                print("❌ Error fetching received links: \(error)")
            }
        }
    }
    
    /// Mark all links as read
    func markAllAsRead() {
        ReadLinkTracker.markAllAsRead(links: allLinks, userID: appleUserID)
    }
    
    /// Refreshes the profile and friends data
    func refreshProfileAndFriends() {
        loadProfileAndFriends()
    }
    
    /// Fetches UserProfile then batch-fetches friends' profiles
    func loadProfileAndFriends() {
        guard !appleUserID.isEmpty else { return }
        
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: appleUserID) { [weak self] result in
            switch result {
            case .success(let profile):
                // profile is already non-optional
                DispatchQueue.main.async {
                    self?.name = profile.fullName
                    self?.selectedImage = profile.image
                    self?.email = profile.email ?? ""
                }
                if profile.fullName.isEmpty {
                    self?.fullName = profile.fullName
                }
                
                let friendIDs = profile.friends
                CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: friendIDs) { [weak self] friendsResult in
                    switch friendsResult {
                    case .success(let profiles):
                        // 1. update UI
                        let names = profiles.map(\.fullName)
                        DispatchQueue.main.async {
                            self?.friendNamesText = names.isEmpty
                            ? "None"
                            : names.joined(separator: ", ")
                        }
                        // 2. write full profiles to App-Group cache
                        ProfileCacheOld.save(profiles)
                       
                    case .failure(let error):
                        print("❌ Failed fetching friends: \(error)")
                    }
                }
                
            case .failure(let error):
                print("❌ Error fetching profile: \(error)")
            }
        }
    }
}

struct UserProfileView: View {
    @StateObject private var vm: UserProfileViewModel
    @ObservedObject private var notificationManager = NotificationManager.shared
    private var showOffers: Bool = false
    @State private var showMarkAllConfirmation = false
    @State private var showInviteFriendSheet = false
    @State private var showAcceptInvitationSheet = false
    @State private var showDebugView = false
    
    init(appleUserID: String = UserDefaults.standard.string(forKey: "evensharely_icloudID") ?? "") {
        _vm = StateObject(wrappedValue: UserProfileViewModel(appleUserID: appleUserID))
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    NavigationLink(destination: UserProfileEditView()) {
                        HStack {
                            if let image = vm.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 50, height: 50)
                                    .overlay(Text("Add").font(.caption))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                if !vm.name.isEmpty {
                                    Text(vm.name)
                                        .font(.headline)
                                } else if !vm.fullName.isEmpty {
                                    Text(vm.fullName)
                                        .font(.headline)
                                } else {
                                    Text("First Last")
                                        .font(.headline)
                                }
                                
                                if !vm.email.isEmpty {
                                    Text(vm.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("sample@example.com")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Friends row
                    NavigationLink(destination: FriendsEditView()) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.primary)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading) {
                                Text("Friends").font(.headline)
                                Text(vm.friendNamesText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Your Profile")
                }
                
                // MARK: - Connections Section
                Section(header: Text("Connections")) {
                    Button(action: {
                        showInviteFriendSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .frame(width: 24, height: 24)
                            Text("Invite a Friend")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        showAcceptInvitationSheet = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode")
                                .frame(width: 24, height: 24)
                            Text("Accept Invitation")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Stats Section
                 Section(header: Text("Your Stats")) {
                     HStack(spacing: 16) {
                         RecordCard(
                             title: "Received Links",
                             value: String(vm.receivedCount),
                             icon: "tray.and.arrow.down")
                         RecordCard(
                             title: "Sent Links",
                             value: String(vm.sentCount),
                             icon: "paperplane")
                     }
                 }
  
                
                // MARK: - Settings Section
                Section(header: Text("Settings")) {
                    // Mark All as Read button
                    Button(action: {
                        showMarkAllConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .frame(width: 24, height: 24)
                            Text("Mark All Messages as Read")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Badge Counter permission button
                    Button(action: {
                        notificationManager.requestBadgePermission()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .frame(width: 24, height: 24)
                            Text("Enable Message Count on App Icon")
                            Spacer()
                            if notificationManager.permissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    
                }
                
                // MARK: - Offers Section (if enabled)
                if showOffers {
                    Section(header: Text("Premium Offers")) {
                        Button(action: { /* action */ }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 24, height: 24)
                                Text("Premium Pass")
                                    .font(.headline)
                                Spacer()
                                Text("Get access to all features")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { /* action */ }) {
                            HStack {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.pink)
                                    .frame(width: 24, height: 24)
                                Text("Gift Premium")
                                    .font(.headline)
                                Spacer()
                                Text("Share with friends")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Version info
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("SquirrelBear is Hungry. Feed Me by Sharing Links!")
                                .font(.caption)
                            Text("Version 1.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Mark All as Read", isPresented: $showMarkAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Mark All as Read", role: .destructive) {
                    vm.markAllAsRead()
                }
            } message: {
                Text("This will mark all your shared links as read and clear the notification badge. This action cannot be undone.")
            }
            .sheet(isPresented: $showInviteFriendSheet) {
                InviteFriendView(userID: vm.appleUserID)
            }
            .sheet(isPresented: $showAcceptInvitationSheet) {
                AcceptInvitationView(
                    userID: vm.appleUserID,
                    onInvitationAccepted: {
                        // Refresh profile and friends after accepting an invitation
                        vm.refreshProfileAndFriends()
                    }
                )
            }
            
        }
    }
}


struct RecordCard: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title)
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    
    // Set the UserDefaults value for the preview environment
    UserDefaults.standard.set(previewID, forKey: "evensharely_icloudID")
    
    // Return the view with the explicit previewID
    return UserProfileView(appleUserID: previewID)
}
