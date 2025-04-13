//
//  ContentView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//
/*
import SwiftUI
import CloudKit

struct OldContentView: View {
    @AppStorage("evensharely_username") var username: String = ""
    @State private var links: [SharedLink] = []
    @State private var showUserSetup = false

    var body: some View {
        NavigationView {
            
            VStack {
                //Handle if user does not exist
                if username.isEmpty {
                    Button("Set Up Profile") {
                        showUserSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showUserSetup) {
                        UserSetupView {
                            showUserSetup = false
                        }
                    }
                }
                //Display Links in list
                else {
                    NavigationView{
                        
                  
                    List(links.sorted(by: { $0.date > $1.date })) { link in
                        LinkRow(link: link)
                    }
                    }
                    Button("🔄 Refresh Inbox") {
                        loadInbox()
                    }
                    .padding()
                }
            }
            .navigationTitle("📥 Inbox")
            .onAppear {
                loadInbox()
            }
            
           
        }
    }

    func loadInbox() {
        CloudKitManager.shared.fetchSharedLinks { result in
            switch result {
            case .success(let fetched):
                print("📥 Loaded \(fetched.count) links from CloudKit")
                links = fetched
            case .failure(let error):
                print("❌ Failed to fetch inbox: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentViewPreviewWrapper: View {
    @State private var mockLinks: [SharedLink] = [
        .mock,
        SharedLink(
            id: CKRecord.ID(recordName: "mock2"),
            url: URL(string: "https://blog.stackademic.com/rich-link-representation-in-swiftui-2f155689fe62")!,
            senderIcloudID: "mock_sender_456", senderFullName: "Mock Sender",
            recipientIcloudIDs: ["mock_recipient_abc"],
            tags: ["news", "opinion"],
            date: Date().addingTimeInterval(-3600)
        ),
        SharedLink(
            id: CKRecord.ID(recordName: "mock3"),
            url: URL(string: "https://www.instagram.com/reel/DIEiFgHurCy/?igsh=aDlub3U3Y3NpMXcz")!,
            senderIcloudID: "mock_sender_456",senderFullName: "Mock Sender",
            recipientIcloudIDs: ["mock_recipient_abc"],
            tags: ["news", "opinion"],
            date: Date().addingTimeInterval(-3600)
        )
    ]

    var body: some View {
        NavigationView {
            List(mockLinks.sorted(by: { $0.date > $1.date })) { link in
                LinkRow(link: link)
            }
            .navigationTitle("📥 Inbox")
        }
    }
}


#Preview {
    ContentViewPreviewWrapper()
}

*/
