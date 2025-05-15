//
//  InviteFriendsView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import SwiftUI

struct InviteFriendView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var invitationCode = ""
    @State private var isGeneratingCode = false
    @State private var isShowingShareSheet = false
    @State private var showCopyAlert = false
    
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
                    InstructionRow(number: 2, text: "They select 'Accept Invitation' in their profile")
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
                                Text("Generate Invitation Code")
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
                            shareInvitation()
                        }) {
                            Label("Share Invitation", systemImage: "square.and.arrow.up")
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
                    Text("Your unique invitation code")
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
                
                // Instructions
//                if !invitationCode.isEmpty {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("How it works:")
//                            .font(.subheadline)
//                            .fontWeight(.semibold)
//                        
//                        InstructionRow(number: 1, text: "Share this code with your friend")
//                        InstructionRow(number: 2, text: "They go to 'Accept Invitation' in their profile")
//                        InstructionRow(number: 3, text: "They enter the code to connect with you")
//                    }
//                    .padding()
//                    .background(Color(.systemGray6))
//                    .cornerRadius(12)
//                    .padding()
//                }
            }
            .navigationTitle("Invite a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Code Copied", isPresented: $showCopyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invitation code copied to clipboard")
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
    
    private func shareInvitation() {
        // We need to get a reference to the UIViewController to present the share sheet
        print("Trying to Share Invitation...")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        FriendInvitationManager.shared.shareInvitation(
            code: invitationCode,
            from: rootViewController) {
                // Optional: handle completion
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

#Preview {
    InviteFriendView(userID: previewID)
}
