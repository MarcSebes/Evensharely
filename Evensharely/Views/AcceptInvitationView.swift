//
//  AcceptInvitationView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import SwiftUI

struct AcceptInvitationView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var invitationCode = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successFriendName = ""
    
    let userID: String
    var onInvitationAccepted: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header with illustration
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)
                
                Text("Accept Friend Invitation")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter the invitation code shared with you to connect with your friend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Invitation code input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invitation Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter code (e.g. ES1A2B3C4)", text: $invitationCode)
                        .font(.title3)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 1)
                                .opacity(invitationCode.isEmpty ? 0 : 1)
                        )
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        acceptInvitation()
                    }) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.horizontal)
                        } else {
                            Text("Accept Invitation")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(invitationCode.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(invitationCode.isEmpty || isProcessing)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to find an invitation code:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    InstructionRow(number: 1, text: "Ask your friend to generate an invitation code")
                    InstructionRow(number: 2, text: "They should share it with you via message")
                    InstructionRow(number: 3, text: "Enter the code exactly as shown")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Accept Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Great!", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                    onInvitationAccepted?()
                }
            } message: {
                Text(successFriendName.isEmpty
                     ? "You are now connected with your friend."
                     : "You are now connected with \(successFriendName).")
            }
        }
    }
    
    private func acceptInvitation() {
        guard !invitationCode.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        // Trim and uppercase the code for consistency
        let cleanCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Use the finalized method
        FriendInvitationManager.shared.finalizedAcceptInvitation(code: cleanCode, byUserID: userID) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let friendUserID):
                    // Try to get the friend's name from the profile cache
                    let cachedUsers = ProfileCache.load()
                    if let cachedFriend = cachedUsers.first(where: { $0.id == friendUserID }) {
                        successFriendName = cachedFriend.fullName
                    }
                    
                    showSuccess = true
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}


#Preview {
    AcceptInvitationView(userID: previewID)
}
