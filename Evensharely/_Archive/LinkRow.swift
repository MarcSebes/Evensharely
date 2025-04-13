//
//  LinkRow.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/7/25.
//
/*
import SwiftUI
import CloudKit
import LinkPresentation

struct LinkRow: View {
    let link: SharedLink
    var previewMetadata: LPLinkMetadata? = nil

    @State private var senderName: String = "Loading..."
    @State private var linkMetadata: LPLinkMetadata?

    //No idea what this does
    struct SizeKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
            value = nextValue()
        }
    }
    var body: some View {
        //Display the Link
        Link(destination: link.url) {
            VStack(alignment: .leading, spacing: 8) {
                   //Date and Sender Name
                   HStack {
                       Text(formattedDate(link.date))
                       Spacer()
                       Text("\(senderName)")
                   }
                   .font(.caption2)
                   .foregroundColor(.gray)
                   .padding(.horizontal)
                //Preview of actual link
                if let metadata = linkMetadata {
                    LinkPreview(metadata: metadata)
                }
                //Tags added by sender
                if !link.tags.isEmpty {
                    Text("Tags: \(link.tags.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            CloudKitManager.shared.fetchUserProfile(forIcloudID: link.senderIcloudID) { result in
                switch result {
                case .success(let profile):
                    senderName = profile?.fullName ?? profile?.username ?? "Unknown"
                case .failure:
                    senderName = "Unknown"
                }
            }

            if let previewMetadata = previewMetadata {
                self.linkMetadata = previewMetadata
                return
            }

            if let cached = MetadataCache.shared.get(for: link.url) {
                self.linkMetadata = cached
            } else {
                LPMetadataProvider().startFetchingMetadata(for: link.url) { metadata, error in
                    if let metadata = metadata {
                        MetadataCache.shared.set(metadata, for: link.url)
                        DispatchQueue.main.async {
                            self.linkMetadata = metadata
                        }
                    }
                }
            }
        }
    }
}

extension LPLinkMetadata {
    static var mock: LPLinkMetadata {
        let metadata = LPLinkMetadata()
        metadata.originalURL = URL(string: "https://www.instagram.com/reel/DIEiFgHurCy/?igsh=aDlub3U3Y3NpMXcz")!
        metadata.url = metadata.originalURL
        metadata.title = "Mock Article Title"
        metadata.iconProvider = NSItemProvider(object: UIImage(systemName: "doc.text")!)
        return metadata
    }
}
extension SharedLink {
    static var mock: SharedLink {
        SharedLink(
            id: CKRecord.ID(recordName: "mock1"),
            url: URL(string: "https://www.instagram.com/reel/DIEiFgHurCy/?igsh=aDlub3U3Y3NpMXcz")!,
            senderIcloudID: "mock_sender_123", senderFullName: "Mock Sender",
            recipientIcloudIDs: ["mock_recipient_abc"],
            tags: ["mock", "preview"],
            date: Date()
        )
    }
}

#Preview {
   LinkRow(link: .mock, previewMetadata: .mock)
}
*/
