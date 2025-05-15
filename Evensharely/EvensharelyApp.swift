//
//  EvensharelyApp.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/5/25.
//

import SwiftUI

@main
struct EvensharelyApp: App {
    // Register the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var auth = AuthenticationViewModel()
    @State private var isInitializing = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    // Optional splash screen or loading indicator
                    LoadingView()
                        .onAppear {
                            // Give a moment for credentials check to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isInitializing = false
                            }
                        }
                } else if auth.isSignedIn {
                    MainTabView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(auth)
        }
    }
}

// Optional loading view to show while checking credentials
struct LoadingView: View {
    let subtitles = ["Gathering Nuts...", "Hunting for Food...", "Hibernating...", "Loading 26% of nuts...", "Stealing picnic baskets...", "Reading books by Deb Pilutti...", "Feeding on links..."]
    @State private var randomItem: String? = nil
    
    var body: some View {
        VStack {
            Image("Friend")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .foregroundColor(.accentColor)
            
            Text("SquirrelBear")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            HStack{
                
                Text(randomItem ?? "Run...")
                    .font(.headline)
                    .padding(.top, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("IconBackground"))
        .onAppear {
            randomItem = subtitles.randomElement()
        }
    }
}
