//
//  MainView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/7/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var tracker = ReactionTracker()
    
    var body: some View {
        TabView {
            Tab("Inbox", systemImage: "tray") {
                ContentView()
            }
            Tab("Favorites", systemImage: "star") {
                FavoritesView()
            }
            Tab("Sent", systemImage: "paperplane") {
                SentView()
                    .environmentObject(tracker)
                    .badge(tracker.newReactionsExist ? "●" : nil)
            }
            Tab("Profile", systemImage: "person.circle") {
                UserSetupView()
            }

            
            
        }
    }
}


#Preview {
    MainView()
}
