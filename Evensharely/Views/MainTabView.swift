//
//  MainView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("evensharely_icloudID") var icloudID: String = ""
    @StateObject private var viewModel: LinkViewModel
    @State private var tagEditingLink: SharedLink?
    
    init() {
        // Access iCloudID before init
        let storedID = UserDefaults.standard.string(forKey: "evensharely_icloudID") ?? ""
        print(storedID)
        _viewModel = StateObject(wrappedValue: LinkViewModel(userID: storedID))
    }
    
    var body: some View {
        TabView {
            // Inbox Tab
            InboxView(
                viewModel: viewModel,
                tagEditingLink: $tagEditingLink
            )
            .tabItem {
                Label("Inbox", systemImage: "tray")
            }
            
            // Sent Tab
            InboxSentView(
                viewModel: viewModel,
                tagEditingLink: $tagEditingLink
            )
            .tabItem {
                Label("Sent", systemImage: "paperplane")
            }
            
            // Favorites Tab
            InboxFavoritesView(
                viewModel: viewModel,
                tagEditingLink: $tagEditingLink
            )
            .tabItem {
                Label("Favorites", systemImage: "star")
            }
            // UserProfile Tab
            UserProfileView()
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            
            
        }
        .sheet(item: $tagEditingLink) { link in
            TagEditorView(sharedLink: link) { newTags in
                viewModel.updateTags(newTags, for: link)
            }
        }
        .onAppear {
            // Make sure we have the correct ID if it changes
            if viewModel.userID != icloudID {
                viewModel.userID = icloudID
            }
        }
    }
}

#Preview {
    MainTabView()
}
