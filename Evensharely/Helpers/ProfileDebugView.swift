import SwiftUI
import Foundation

struct ProfileDebugView: View {
    @State private var currentProfile: UserProfile?
    @State private var friendProfiles: [UserProfile] = []
    @State private var errorMessage: String?
    @State private var otherProfile: UserProfile?
    @State private var previewID: String = "000866.c7c9a90c75834932b91822b2739c37ce.2033"
    @State private var usePreview: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    // -- Current User -- //
                    if let profile = currentProfile {
                        Section("You") {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let image = profile.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                            .onTapGesture {pGesture in
                                                UIPasteboard.general.setValue(profile.appleUserID, forPasteboardType: "public.plain-text")
                                            }
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(profile.fullName)")
                                        .font(.title3).bold()
                                    Text("\(profile.email ?? "–")")
                                        .font(.caption)
                                }
                            }
                        }
                        
                        // -- Friends of Current User -- //
                        if !friendProfiles.isEmpty {
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
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.fullName).font(.title3).bold()
                                            Text("\(friend.email ?? "–")")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .onTapGesture {pGesture in
                                        UIPasteboard.general.setValue(profile.appleUserID, forPasteboardType: "public.plain-text")
                                        
                                    }
                                }
                            }
                            
                        }
                        
                        
                        
                    } else if let errorMessage = errorMessage {
                        Text("❌ Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } else {
                        Text("Loading…")
                    }
                    
                    
                }
                .navigationTitle("You and Your Friends")
                Button("Invite a Friend") {
                    //TODO: Add Invitation Logic
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            
        }
        .onAppear(perform: loadProfiles)
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

#Preview {
    ProfileDebugView()
}
