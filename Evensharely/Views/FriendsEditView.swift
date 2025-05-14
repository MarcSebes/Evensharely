//
//  FriendsEditView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/18/25.
//

import SwiftUI
import CloudKit
import MessageUI

/// View for managing the user's list of friends: view, delete, invite via SMS with deep link, and add via code.
struct FriendsEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("evensharely_icloudID") private var icloudID: String = ""

    @State private var loadedProfile: UserProfile?
    @State private var friendProfiles: [UserProfile] = []
    @State private var inviteCode: String = ""
    @State private var errorMessage: String?

    // SMS composer presentation
    @State private var showMessageComposer = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Your Friends
                Section(header: Text("Your Friends")) {
                    if friendProfiles.isEmpty {
                        Text("No friends added yet.")
                    } else {
                        ForEach(friendProfiles) { friend in
                            Text(friend.fullName)
                        }
                        .onDelete(perform: removeFriends)
                    }
                }

                // MARK: Invite via SMS
                Section(header: Text("Invite a Friend")) {
                    Button("Send Invite") {
                        showMessageComposer = true
                    }
                }

                // MARK: Add by Code
                Section(header: Text("Add a Friend by Code")) {
                    HStack {
                        TextField("Enter invite code", text: $inviteCode)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("Add") {
                            addFriend(code: inviteCode)
                        }
                        .disabled(inviteCode.isEmpty)
                    }
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Manage Friends")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadProfile)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(isPresented: $showMessageComposer) {
                let inviteURL = "evensharely://addFriend?code=\(icloudID)"
                MessageComposeView(
                    recipients: [],  // user picks recipient
                    body: "Join me on Evensharely! Tap to add me as a friend: \(inviteURL)"
                ) { _ in
                    showMessageComposer = false
                }
            }
        }
    }

    // MARK: - Deep Link
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "evensharely",
              url.host == "addFriend",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        addFriend(code: code)
    }

    // MARK: - Data Operations
    private func loadProfile() {
        guard !icloudID.isEmpty else { return }
        CloudKitManager.shared.fetchUserProfile(forIcloudID: icloudID) { result in
            switch result {
            case .success(let maybeProfile):
                if let profile = maybeProfile {
                    loadedProfile = profile
                    loadFriendProfiles(from: profile.friends)
                }
            case .failure(let error):
                print("❌ Failed to load user profile: \(error)")
            }
        }
    }

    private func loadFriendProfiles(from ids: [String]) {
        CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: ids) { result in
            switch result {
            case .success(let profiles):
                friendProfiles = profiles
            case .failure(let error):
                print("❌ Failed to load friends: \(error)")
            }
        }
    }

    private func saveProfile(_ profile: UserProfile) {
        CloudKitManager.shared.saveUserProfile(profile, image: profile.image) { result in
            if case let .failure(error) = result {
                print("❌ Error saving updated profile: \(error)")
            }
        }
    }

    private func removeFriends(at offsets: IndexSet) {
        guard var profile = loadedProfile else { return }
        offsets.forEach { idx in
            let removed = friendProfiles[idx]
            if let index = profile.friends.firstIndex(of: removed.icloudID) {
                profile.friends.remove(at: index)
            }
        }
        loadedProfile = profile
        saveProfile(profile)
        loadFriendProfiles(from: profile.friends)
    }

    /// Adds a friend by their iCloudID code and updates both profiles reciprocally.
    private func addFriend(code: String) {
        errorMessage = nil
        // fetch the other user
        CloudKitManager.shared.fetchUserProfile(forIcloudID: code) { result in
            switch result {
            case .success(let maybeFriend):
                guard let friend = maybeFriend else {
                    errorMessage = "No user with that code"
                    return
                }
                guard var profile = loadedProfile else { return }
                // prevent adding self
                if friend.icloudID == icloudID {
                    errorMessage = "You cannot add yourself."
                    return
                }
                // prevent duplicates
                if profile.friends.contains(friend.icloudID) {
                    errorMessage = "Already friends with \(friend.fullName)"
                    return
                }
                // update current user's list
                profile.friends.append(friend.icloudID)
                saveProfile(profile)
                // update friend's list reciprocally
                var friendProfile = friend
                if !friendProfile.friends.contains(icloudID) {
                    friendProfile.friends.append(icloudID)
                    CloudKitManager.shared.saveUserProfile(friendProfile, image: friendProfile.image) { _ in }
                }
                // reload local
                loadedProfile = profile
                loadFriendProfiles(from: profile.friends)
                inviteCode = ""
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - MessageComposeView Wrapper

struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var onComplete: (MessageComposeResult) -> Void

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposeView
        init(_ parent: MessageComposeView) { self.parent = parent }
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.parent.onComplete(result)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }

    func updateUIViewController(
        _ uiViewController: MFMessageComposeViewController,
        context: Context) { }
}


#Preview {
   // FriendsEditView()
}
