//
//  UserListTestView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/7/25.
//

import SwiftUI

struct UserListTestView: View {
    @State private var users: [UserProfile] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading users...")
                } else if users.isEmpty {
                    Text("No users found")
                } else {
                    List(users, id: \.id) { user in
                        VStack(alignment: .leading) {
                            Text(user.fullName)
                                .font(.headline)
                            Text(user.username)
                                .font(.subheadline)
                            Text("Joined: \(user.joined.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Button("Fetch User Profiles") {
                    loadUsers()
                }
                .padding()
            }
            .navigationTitle("🔍 View All Users")
        }
    }

    func loadUsers() {
        isLoading = true
        CloudKitManager.shared.fetchAllUserProfiles { result in
            isLoading = false
            switch result {
            case .success(let fetched):
                print("✅ Loaded \(fetched.count) users")
                users = fetched
            case .failure(let error):
                print("❌ Failed to fetch users: \(error.localizedDescription)")
            }
        }
    }
}


#Preview {
    UserListTestView()
}
