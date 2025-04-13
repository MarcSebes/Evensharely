//
//  FriendsView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/8/25.
//

import SwiftUI
import CloudKit
import LinkPresentation

struct FriendsView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @State private var friends: [UserProfile] = []
    @State private var isLoading = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading friends...")
                } else if friends.isEmpty {
                    Text("You haven’t added any friends yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    VStack{
                        VStack{
                            List(friends) { user in
                                HStack(spacing: 12) {
                                    if let image = user.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(.systemGray4))
                                            .frame(width: 40, height: 40)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(user.fullName)
                                            .font(.headline)
                                        Text(user.username)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .background(Color.white.opacity(0.9))
                    }
                    
                }
                Button("Invite a Friend") {
                    showShareSheet = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                .sheet(isPresented: $showShareSheet) {
                    let inviteText = "Hey! Join me on Evensharely — it’s a simple way to share links. Use this code to connect with me: \n\n\(icloudID)"
                    ActivityView(activityItems: [inviteText])
                }
            }
            .padding()
            .navigationTitle("Your Friends")
        }
        .onAppear(perform: loadFriends)
    }

    func loadFriends() {
        guard !icloudID.isEmpty else { return }
        isLoading = true

        CloudKitManager.shared.fetchUserProfile(forIcloudID: icloudID) { result in
            switch result {
            case .success(let profile):
                guard let profile = profile else {
                    isLoading = false
                    return
                }

                let friendIDs = profile.friends
                CloudKitManager.shared.fetchUserProfiles(forIcloudIDs: friendIDs) { result in
                    isLoading = false
                    switch result {
                    case .success(let users):
                        self.friends = users
                    case .failure(let error):
                        print("❌ Failed to fetch friends: \(error.localizedDescription)")
                    }
                }

            case .failure(let error):
                isLoading = false
                print("❌ Failed to load profile: \(error.localizedDescription)")
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FriendsView(icloudID: "_e625da7a3ca0e60d88415fa21c57927c")
    
}
