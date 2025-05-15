//
//  UserProfileEditView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/18/25.
//

import SwiftUI
import CloudKit
import PhotosUI

/// A view for creating or editing the user's full name and profile image.
struct UserProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("evensharely_icloudID") private var appleUserID: String = ""
    
    @State private var loadedProfile: UserProfile? = nil
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Image
                Section(header: Text("Profile Image")) {
                    VStack(alignment: .center, spacing: 10) {
                        if let uiImage = selectedImage {
                            Image(uiImage: uiImage)
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
                        PhotosPicker(
                            "Select Image",
                            selection: $photoPickerItem,
                            matching: .images,
                            photoLibrary: .shared()
                        )
                        .onChange(of: photoPickerItem) { oldItem, newItem in
                            guard let item = newItem else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = uiImage
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                }
                ///Name
                Section(header: Text("Name")) {
                    TextField("Enter your full name", text: $fullName)
                        .disableAutocorrection(true)
                }
                /// Email
                Section(header: Text("Email")) {
                    TextField("Enter your Email Address", text: $email)
                        .disableAutocorrection(true)
                }
                /// AppleID
                Section(header: Text("Apple ID")) {
                    TextField("Your Apple ID", text: $appleUserID)
                        .disabled(true)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.gray)
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = appleUserID
                    }
                    .font(.caption)
                }
                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(loadedProfile == nil ? "Create Profile" : "Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(fullName.isEmpty || isSaving)
                }
            }
            .onAppear(perform: fetchProfile)
        }
    }
    
    // MARK: - Data
    
    private func fetchProfile() {
        guard !appleUserID.isEmpty else { return }
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: appleUserID) { result in
            switch result {
            case .success(let maybeProfile):
                let profile = maybeProfile
                loadedProfile = profile
                fullName = profile.fullName
                email    = profile.email ?? ""
                selectedImage = profile.image
            case .failure(let error):
                print("❌ Failed to load profile: \(error)")
            }
        }
    }
    
    private func saveProfile() {
        guard !appleUserID.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        
        // Use existing record ID or generate new one
        let recordID = loadedProfile?.id ?? CKRecord.ID(recordName: UUID().uuidString)
        // Preserve other fields
        let existingFriends = loadedProfile?.friends ?? []
        //        let username = loadedProfile?.username ?? generateUsername(from: fullName)
        let joinedDate = loadedProfile?.joined ?? Date()
        
        // Build new profile
        let profile = UserProfile(
            id: recordID,
            icloudID: "",
            username: "",
            fullName: fullName,
            joined: joinedDate,
            image: selectedImage,
            friends: existingFriends,
            appleUserID: appleUserID,
            email: email
        )
 
    }
}


#Preview {
    UserProfileEditView()
}
