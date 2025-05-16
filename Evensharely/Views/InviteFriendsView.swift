//
//  InviteFriendsView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import SwiftUI
import MessageUI

struct InviteFriendView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var invitationCode = ""
    @State private var isGeneratingCode = false
    @State private var isMessageComposePresented = false
    @State private var showCopyAlert = false
    @State private var canSendMessages = MFMessageComposeViewController.canSendText()
    
    let userID: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header with illustration
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color("IconBackground"))
                    .padding(.top, 20)
                
                Text("SquirrelBear Needs Friends")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it Works:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    InstructionRow(number: 1, text: "Share this code with your friend")
                    InstructionRow(number: 2, text: "They select 'Accept an Invie' in their profile")
                    InstructionRow(number: 3, text: "They enter the code and you are friends forever!")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                
//                Text("Connect with friends, share links from anywhere, they view them in one place.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
                
                // Invitation code section
                // Action buttons
                VStack(spacing: 16) {
                    if invitationCode.isEmpty {
                        Button(action: {
                            generateCode()
                        }) {
                            if isGeneratingCode {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.horizontal)
                            } else {
                                Text("Generate Invite Code")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("IconBackground"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isGeneratingCode)
                    } else {
                        Button(action: {
                            if canSendMessages {
                                isMessageComposePresented = true
                            } else {
                                // Handle devices that can't send messages
                                UIPasteboard.general.string = invitationCode
                                showCopyAlert = true
                            }
                        }) {
                            Label(canSendMessages ? "Send Invite to a Friend" : "Copy Invite",
                                  systemImage: canSendMessages ? "message.fill" : "doc.on.doc")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("IconBackground"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Text("Your unique invite code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(invitationCode.isEmpty ? "Generate a code to share" : invitationCode)
                            .font(.title3)
                            .fontWeight(invitationCode.isEmpty ? .regular : .bold)
                            .foregroundColor(invitationCode.isEmpty ? .secondary : .primary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if !invitationCode.isEmpty {
                            Button(action: {
                                UIPasteboard.general.string = invitationCode
                                showCopyAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.headline)
                                    .padding(10)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            
                        }
                    }
                    .frame(height: 50)
                }
                .padding(.horizontal)
                

                
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal)
                
            }
            .sheet(isPresented: $isMessageComposePresented) {
                            MessageComposeView(
                                recipients: [], // User will select recipient
                                body: "Join me on Squirrel Bear!\n Use this invite code: \(invitationCode)",
                                completion: { _ in
                                    isMessageComposePresented = false
                                }
                            )
                        }
            .navigationTitle("Invite a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Code Copied", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invite code copied to clipboard")
            }
            
        }
    }
    
    private func generateCode() {
        isGeneratingCode = true
        
        // Use a small delay to show loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            invitationCode = FriendInvitationManager.shared.generateInvitationCode(for: userID)
            isGeneratingCode = false
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color("IconBackground")))
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// Message Compose View
struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var completion: (MessageComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposeView
        
        init(_ parent: MessageComposeView) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                         didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.parent.completion(result)
            }
        }
    }
}
#Preview {
    InviteFriendView(userID: previewID)
}
