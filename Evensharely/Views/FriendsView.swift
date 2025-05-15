//
//  FriendsView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/14/25.
//

import SwiftUI

struct FriendsView: View {
    @State private var showInviteFriendSheet = false
    @State private var showAcceptInvitationSheet = false
    @State var appleUserID: String = UserDefaults.standard.string(forKey: "evensharely_icloudID") ?? ""
    
    @State private var currentProfile: UserProfile?
    @State private var friendProfiles: [UserProfile] = []
    @State private var errorMessage: String?

    
    var body: some View {
        NavigationStack{
            List{
                // MARK: - Friends Section

                    Section("Your Friends") {
                        ForEach(friendProfiles, id: \.id) { friend in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let image = friend.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                    } else {
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 50, height: 50)
                                    }
                                    
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(friend.fullName)
                                        .font(.headline)
                                        .foregroundStyle(Color(.systemGray))
                                    Text("\(friend.email ?? "–")")
                                        .font(.caption)
                                        .foregroundStyle(Color(.systemGray))
                               }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    

                Section(header: Text("Invitations")) {
                    /// Invitation Start
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
                            Text("Accept an Invitation")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    /// Invitation End
                }
            }
            .sheet(isPresented: $showInviteFriendSheet) {
                InviteFriendView(userID: appleUserID)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAcceptInvitationSheet) {
                AcceptInvitationView(
                    userID: appleUserID,
                    onInvitationAccepted: {
                        // Refresh friends after accepting an invitation
                        loadProfiles()
                    }
                )
            }
        }
        .onAppear {
            loadProfiles()
        }
    }
    
    private func loadProfiles() {
        // 1) Grab the current AppleID from App-Group defaults
        let suite = UserDefaults(suiteName: "group.com.marcsebes.evensharely")
       
       // Use the AppleID for the User or fallback to Mine
        let appleID = suite?.string(forKey: "evensharely_icloudID") ?? "000866.c7c9a90c75834932b91822b2739c37ce.2033"

        // 2) Fetch the current user's profile
     
        CloudKitManager.shared.fetchPrivateUserProfile(forAppleUserID: appleID) { result in
            switch result {
            case .failure(let err):
                errorMessage = err.localizedDescription

            case .success(let profile):
                self.currentProfile = profile
        

                // 3) Fetch each friend
                CloudKitManager.shared.fetchUserProfiles(forappleUserIDs: profile.friends) { res in
                    switch res {
                    case .failure(let err):
                        errorMessage = err.localizedDescription
                    case .success(let friends):
                        self.friendProfiles = friends
                    }
                }
            }
        }
        
    }
}



#Preview ("FriendView") {
    FriendsView()
}
