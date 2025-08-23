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
import UIKit

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
    @Published var friendCount: Int = 0
    
    
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
                    self?.friendCount = profile.friends.count
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
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var vm: UserProfileViewModel
    @ObservedObject private var notificationManager = NotificationManager.shared
    private var showOffers: Bool = false
    @State private var showMarkAllConfirmation = false
    @State private var showInviteFriendSheet = false
    @State private var showAcceptInvitationSheet = false
    @State private var showDebugView = false
    @State private var isPresented: Bool = false
    @ObservedObject private var preferences = AppPreferences.shared
    
    
    init(appleUserID: String = UserDefaults.standard.string(forKey: "evensharely_icloudID") ?? "") {
        _vm = StateObject(wrappedValue: UserProfileViewModel(appleUserID: appleUserID))
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    NavigationLink(destination: UserProfileEditView()) {
                        HStack (spacing: 20){
                            if let image = vm.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 60)
                                    .overlay(Text("Add").font(.caption))
                            }
                            VStack(alignment: .leading, spacing: 10) {
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
                                /*
                                if !vm.email.isEmpty {
                                    Text(vm.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No email Provided")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                 */
                                HStack (spacing: 30){
                                    VStack (alignment: .leading){
                                        Text(String(vm.sentCount))
                                            
                                        Text("Shared")
                                            .font(.caption)
                                    }

                                    VStack (alignment: .leading){
                                        Text(String(vm.receivedCount))
                                        Text("Received")
                                            .font(.caption)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(String(vm.friendCount))
                                        Text("Friends")
                                            .font(.caption)
                                    }

                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    // Friends row

                    

                } header: {
                    Text("Your Profile")
                }
                
                // MARK: - Friends Section
                Section(header: Text("Friends")) {
                    NavigationLink(destination: FriendsView()) {
                        HStack (spacing: 20){
                            Image(systemName: "person.2.fill")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Manage Friends").font(.headline)
                                Text(vm.friendNamesText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                            }
                        }
                        
                    }
                 /// Invitation Start
                    Button(action: {
                        showInviteFriendSheet = true
                    }) {
                        HStack (spacing: 20){
                            Image(systemName: "person.badge.plus")
                                .frame(width: 24, height: 24)
                            Text("Invite a New Friend")

                        }
                       
                        
                    }
                    .buttonStyle(.navigation)
                    
                    
                    Button(action: {
                        showAcceptInvitationSheet = true
                    }) {
                        HStack (spacing: 20){
                            Image(systemName: "qrcode")
                                .frame(width: 24, height: 24)
                            Text("Accept an Invite")
                        }
                      
                    }
                    .buttonStyle(.navigation)
                    /// Invitation End
                }
                
                // MARK: - Stats Section
                 Section(header: Text("Inspiration")) {
                     VStack (alignment: .leading) {
                         VStack (alignment: .trailing){
                             if vm.receivedCount > vm.sentCount {
                                 Text("\"You have great friends. Remember to share everything with them. Everything!\"")
                                    
                                 Text("-SquirrelBear\n")
                                    
                             } else if vm.receivedCount < vm.sentCount {
                                 
                                 Text("\"You already know there is no such thing as oversharing with your friends!\"")
                                 Text("-SquirrelBear\n")
                             }
                         }
                         .frame(maxWidth: .infinity)
                         .foregroundStyle(.secondary)
   
                         

                        
                         
//                         HStack(spacing: 16) {
//                             RecordCard(
//                                title: "Received Links",
//                                value: String(vm.receivedCount),
//                                icon: "tray.and.arrow.down")
//                             RecordCard(
//                                title: "Sent Links",
//                                value: String(vm.sentCount),
//                                icon: "paperplane")
//                         }

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
                    .foregroundStyle(.primary)
                    
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
                    .foregroundStyle(.primary)

                    // New Notification Settings Button
                    Button(action: {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .frame(width: 24, height: 24)
                            Text("Open Notification Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    // Large or Small Inbox
                    Button(action: {
//  //
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .frame(width: 24, height: 24)
                            
                            
                            Toggle("Use Condensed Inbox", isOn: $preferences.useCondensedInbox)

                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                // MARK: - Offers Section (if enabled)
                if showOffers {
                    Section(header: Text("Premium Offers")) {
                        Button(action: {
                            //
                            
                        }) {
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
                        Button("Present alert") {
                            isPresented = true
                        }.alert("Alert title", isPresented: $isPresented, actions: {
                            // Leave empty to use the default "OK" action.
                        }, message: {
                            Text("Alert message")
                        })
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
