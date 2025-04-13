//
//  AllTheLinksView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI
import Foundation

struct AllTheLinksView: View {
    func dumpSharedLinks() {
        CloudKitManager.shared.fetchAllSharedLinks { result in
            switch result {
            case .success(let records):
                print("📦 Fetched \(records.count) SharedLink records")
                for record in records {
                    let url = record["url"] as? String ?? "missing"
                    let sender = record["senderIcloudID"] as? String ?? "missing"
                    let recipients = record["recipientIcloudIDs"] as? [String] ?? []
                    let date = record["date"] as? Date ?? Date.distantPast
                    let tags = record["tags"] as? [String] ?? []

                    print("""
                    🔗 URL: \(url)
                    🧑‍🚀 Sender: \(sender)
                    👥 Recipients: \(recipients.joined(separator: ", "))
                    🏷️ Tags: \(tags.joined(separator: ", "))
                    📅 Date: \(date)
                    ---
                    """)
                }

            case .failure(let error):
                print("❌ Failed to fetch SharedLinks: \(error.localizedDescription)")
            }
        }
    }

    var body: some View {
        Button("Do it!") {
            dumpSharedLinks()
        }
    }
}

#Preview {
    AllTheLinksView()
}
