//
//  UserSetupView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//

import SwiftUI
import CloudKit
import PhotosUI
import UserNotifications

struct UserSetupView: View {
    @AppStorage("evensharely_username") var username: String = ""
    @AppStorage("evensharely_icloudID") var icloudID: String = ""

    @State private var fullName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var profileSaved = false
    @State private var profileLoaded = false
    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var userProfileID: CKRecord.ID? = nil
    @State private var inviteCode: String = ""
    var onComplete: (() -> Void)? = nil


    func requestBadgePermission() {
        let options: UNAuthorizationOptions = [.badge]

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("❌ Notification auth error: \(error.localizedDescription)")
            } else {
                print(granted ? "✅ Badge permission granted" : "🚫 Badge permission denied")
            }
        }
    }
    var body: some View {
        NavigationView {
            
            VStack {
                Form {
                    Section(header: Text("Your Name")) {
                        TextField("e.g. Taylor Swift", text: $fullName)
                    }
                    Section(header: Text("Profile Image")) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 100, height: 100)
                                    .overlay(Text("Add Photo").font(.caption))
                            }

                            PhotosPicker("Choose Image", selection: $photoPickerItem, matching: .images)
                                .onChange(of: photoPickerItem, initial: false) { oldItem, newItem in
                                    guard let newItem else { return }
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            selectedImage = image
                                        }
                                    }
                                }



                        }

                    }
                    Section(header: Text("Invite Code (optional)")) {
                        TextField("Paste invite code", text: $inviteCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    Section(header: Text("Profile Details")) {
                        HStack {
                            Text("Username:")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(username)
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                        HStack {
                            Text("iCloud ID:")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(icloudID.prefix(8) + "...")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }

                    }
                    
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                    
                    if profileSaved {
                        Text("✅ Profile saved!")
                            .foregroundColor(.green)
                            .transition(.opacity)
                            .padding(.top)
                    }
                }
                .navigationBarTitle("Profile Settings")
                .navigationBarItems(trailing: Button("Save") {
                    saveOrUpdateUser()
                }.disabled(fullName.isEmpty || isSaving))
                .onAppear {
                    fetchProfile()
                }
            }
        }
    }
 
    func fetchProfile() {
        guard !icloudID.isEmpty else {
            print("❌ No icloudID in AppStorage")
            return
        }

        CloudKitManager.shared.fetchUserProfile(forIcloudID: icloudID) { result in
            switch result {
            case .success(let profile):
                if let profile = profile {
                    self.fullName = profile.fullName
                    self.profileLoaded = true
                    self.username = profile.username
                    self.selectedImage = profile.image
                    self.userProfileID = profile.id
                } else {
                    print("❌ No matching UserProfile found for iCloudID")
                }
            case .failure(let error):
                print("❌ Error fetching profile: \(error.localizedDescription)")
            }
        }
    }
    func generateUsername(from fullName: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics
        return fullName
            .lowercased()
            .components(separatedBy: allowedCharacters.inverted)
            .joined()
    }

    func saveOrUpdateUser() {
        isSaving = true
        profileSaved = false
        errorMessage = nil

        let container = CloudKitConfig.container
        container.fetchUserRecordID { recordID, error in
            if let error = error {
                print("❌ Failed to fetch iCloud ID: \(error.localizedDescription)")
                isSaving = false
                return
            }

            guard let icloudRecordID = recordID else {
                isSaving = false
                return
            }

            let recordID = userProfileID ?? CKRecord.ID(recordName: UUID().uuidString)
            let cleanedUsername = generateUsername(from: fullName)
            let finalUsername = cleanedUsername.isEmpty ? "user\(UUID().uuidString.prefix(6))" : cleanedUsername

            func saveProfile(friends: [String]) {
                let profile = UserProfile(
                    id: recordID,
                    icloudID: icloudRecordID.recordName,
                    username: finalUsername,
                    fullName: fullName,
                    joined: Date(),
                    friends: friends
                )

                CloudKitManager.shared.saveUserProfile(profile, image: selectedImage) { result in
                    isSaving = false
                    switch result {
                    case .success():
                        UserDefaults.standard.set(profile.username, forKey: "evensharely_username")
                        UserDefaults.standard.set(profile.icloudID, forKey: "evensharely_icloudID")
                        profileSaved = true
                        requestBadgePermission()

                        if !inviteCode.isEmpty {
                            CloudKitManager.shared.fetchUserProfile(forIcloudID: inviteCode) { result in
                                switch result {
                                case .success(let invitedProfile):
                                    if let invited = invitedProfile {
                                        print("✅ Valid invite found: \(invited.username)")

                                        // Update and re-save profile with new friend
                                        var updatedProfile = profile
                                        if !updatedProfile.friends.contains(invited.icloudID) {
                                            updatedProfile.friends.append(invited.icloudID)

                                            CloudKitManager.shared.saveUserProfile(updatedProfile, image: selectedImage) { _ in
                                                print("✅ Friend added to profile")
                                            }
                                        }
                                    } else {
                                        print("❌ No user found with invite code: \(inviteCode)")
                                    }

                                case .failure(let error):
                                    print("❌ Error checking invite code: \(error.localizedDescription)")
                                }
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onComplete?()
                        }

                        profileLoaded = true
                        print("✅ Profile saved")
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        print("❌ Error saving profile: \(error.localizedDescription)")
                    }
                }
            }

            if profileLoaded {
                CloudKitManager.shared.fetchUserProfile(forIcloudID: icloudRecordID.recordName) { result in
                    switch result {
                    case .success(let existingProfile):
                        let friends = existingProfile?.friends ?? []
                        saveProfile(friends: friends)
                    case .failure:
                        saveProfile(friends: [])
                    }
                }
            } else {
                saveProfile(friends: [])
            }
        }
    }

}


#Preview {
    UserSetupView()
}
