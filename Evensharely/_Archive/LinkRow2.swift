//
//  LinkRow2.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/9/25.
//
/*
import SwiftUI
import CloudKit
import LinkPresentation

struct LinkRow2: View {
    let link: SharedLink
    var previewMetadata: LPLinkMetadata? = nil

    @State private var senderName: String = "Loading..."
    @State private var linkMetadata: LPLinkMetadata?

    
    
    
    struct SizeKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
            value = nextValue()
        }
    }
    var body: some View {

       
        
        
        Link(destination: link.url) {
            VStack(alignment: .leading, spacing: 8) {
               VStack(alignment: .trailing) {
                   Text(formattedDate(link.date))
                       .font(.caption)
                       .foregroundColor(Color.gray)

                }

                if let metadata = linkMetadata {
                        
                    LinkPreview(metadata: metadata)
                    

                }
/*
 //This stuff was pretty useless, I think
 Text(link.url.host ?? "Link")
       .font(.headline)
ext(link.url.absoluteString)
       .font(.caption)
       .lineLimit(1)
 */
                HStack {
                    Text("From: \(senderName)")

                    
                }
                .font(.caption2)
                .foregroundColor(.gray)

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






#Preview {
   // LinkRow2(
}
*/
