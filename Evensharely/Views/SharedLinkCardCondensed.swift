//
//  SharedLinkCardCondensed.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/16/25.
//


import SwiftUI
import CloudKit

struct SharedLinkCardCondensed: View {
    let link: SharedLink
    let icloudID: String
    let reactions: [Reaction]
    let isRead: Bool?
    let isFavorited: Bool
    let showReadDot: Bool
    let showSender: Bool
    let recipientText: String?
    let onOpen: () -> Void
    let onFavoriteToggle: (() -> Void)?
    let onReact: ((String) -> Void)?
    init(
        link: SharedLink,
        icloudID: String,
        reactions: [Reaction],
        isRead: Bool? = nil,
        isFavorited: Bool = false,
        showReadDot: Bool = false,
        showSender: Bool = true,
        recipientText: String? = nil,
        onOpen: @escaping () -> Void,
        onFavoriteToggle: (() -> Void)? = nil,
        onReact: ((String) -> Void)? = nil
    ) {
        self.link = link
        self.icloudID = icloudID
        self.reactions = reactions
        self.isRead = isRead
        self.isFavorited = isFavorited
        self.showReadDot = showReadDot
        self.showSender = showSender
        self.recipientText = recipientText
        self.onOpen = onOpen
        self.onFavoriteToggle = onFavoriteToggle
        self.onReact = onReact
    }
    
    @State private var previewHeight: CGFloat = 200 // default fallback height
    private var debugOn: Bool = false
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {  //need more horizontal whitespace outside this VStack
                
                // --------------------//
                //Display Header
                // --------------------//
                
                VStack {
                    HStack(alignment: .center, spacing: 10) {
                        Text(formattedDate(link.date))

                        Spacer()
                        Text(link.senderFullName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                       Spacer()
                        if showReadDot, let isRead, !isRead {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }

                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                //End Display Header
                
                Button(action: onOpen) {
                    ZStack(alignment: .topTrailing) {
                        LinkItemView(link: link.url.absoluteString)


                        // --------------------//
                        //Display Favorite Star Overlay
                        // --------------------//
//                        if let onFavoriteToggle = onFavoriteToggle {
//                            Button(action: onFavoriteToggle) {
//                                Circle()
//                                    .fill(isFavorited ? Color.yellow.opacity(0.9) : Color.black.opacity(0.3))
//                                    .frame(width: 20, height: 20)
//                                    .overlay(
//                                        Image(systemName: isFavorited ? "star.fill" : "star")
//                                            .foregroundColor(.white)
//                                            .font(.system(size: 12))
//                                    )
//                                
//                                    .padding(0)
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                //End Favorite Star Overlay
 
                // --------------------//
                // If in debugMode,
                // add space below it
                // --------------------//
                if debugOn {
                    VStack{
                        Spacer()
                    }
                }
                
                // End debug spacing ---//
                
                
                
                
                // --------------------//
                // Reaction Block
                // --------------------//
                
                
                
                
                
                // --------------------//
                //Display Tags
                // --------------------//
                if !link.tags.isEmpty {
                    HStack(alignment: .center, spacing: 10) {
                        Text("\(link.tags.joined(separator: ", "))")
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal)
                    
                }
                HStack {
                    ForEach(["👍", "❤️", "😂", "😮"], id: \.self) { emoji in
                        let count = reactions.filter { $0.reactionType == emoji }.count
                        let userSelected = reactions.contains { $0.reactionType == emoji && $0.userID == icloudID }
                        
                        Button(action: {
                            onReact?(emoji)
                        }) {
                            Text("\(emoji) \(count)")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(userSelected ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                } //End reaction Block
                .font(.caption)
                .padding()

            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
    }
    
    
}
    struct SharedLinkCardPreviewCondensed: View {
        var body: some View {
            let linkID = CKRecord.ID(recordName: "sample-link-id")
            let userID = "_e625da7a3ca0e60d88415fa21c57927c"
            
            return SharedLinkCardCondensed(
                link: SharedLink(
                    id: linkID,
                    url: URL(string: "https://www.instagram.com/reel/DIb-jIUS63C/?utm_source=ig_web_copy_link")!,
                    senderIcloudID: "_8e6d6d95ea597e372b720835e8141fd7",
                    senderFullName: "Kelly Sebes",
                    recipientIcloudIDs: ["_e625da7a3ca0e60d88415fa21c57927c"],
                    tags: ["dogs","animals"],
                    date: Date()
                ),
                icloudID: userID,
                reactions: [
                    Reaction(id: CKRecord.ID(recordName: "reaction-2"), linkID: linkID, userID: "_e625da7a3ca0e60d88415fa21c57927c", reactionType: "❤️", timestamp: Date())
                ],
                isRead: false,
                isFavorited: true,
                showReadDot: true,
                showSender: true,
                recipientText: nil,
                onOpen: { print("📬 Opened link!") },
                onFavoriteToggle: { print("⭐️ Toggled favorite!") },
                onReact: { emoji in print("Reacted with \(emoji)") }
            )
            .padding()
        }
    }


    #Preview {
        SharedLinkCardPreviewCondensed()
    }

    


