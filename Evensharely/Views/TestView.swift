//
//  TestEmptyMessage.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI

struct TestView: View {
    let subtitles = ["Gathering Nuts...", "Hunting for Food...", "Hibernating..."]
        @State private var randomItem: String? = nil
    @State private var showAlert = false
    @State private var allUsers: [CachedUser] = [CachedUser(id:"1", fullName: "Kely Sebes"), CachedUser(id:"2", fullName: "Brandon Sebes"), CachedUser(id:"3", fullName: "Clarissa Sebes"), CachedUser(id:"4", fullName: "Marc Sebes"), CachedUser(id:"5", fullName: "Bucky")]
    @State private var selectedRecipients: Set<String> = []  
    
    var body: some View {
        
        NavigationStack {
            VStack {
                // Recipients List
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipients").font(.headline)
                    if allUsers.isEmpty {
                        Text("To begin sharing, add friends in the app!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        
                        
                        
                        
                        List{
                            ForEach(allUsers, id: \ .id) { user in
                                Button {
                                    if selectedRecipients.contains(user.id) {
                                        selectedRecipients.remove(user.id)
                                    } else {
                                        selectedRecipients.insert(user.id)
                                    }
                                } label: {
                                    HStack {
                                        Text(user.fullName.isEmpty ? user.id : user.fullName)
                                        Spacer()
                                        if selectedRecipients.contains(user.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color("IconBackground"))
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(Color(Color.primary.opacity(0.1)))
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            
            
            
            
            
            
            
            
            
            
            ScrollView {

                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(allUsers, id: \ .id) { user in
                            Button {
                                if selectedRecipients.contains(user.id) {
                                    selectedRecipients.remove(user.id)
                                } else {
                                    selectedRecipients.insert(user.id)
                                }
                            } label: {
                                HStack {
                                    Text(user.fullName.isEmpty ? user.id : user.fullName)
                                    Spacer()
                                    if selectedRecipients.contains(user.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    
                    
                    
                    
                    Button(action: {
                        showAlert = true
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundStyle(Color.black.opacity(0.2))
                        .cornerRadius(12)
                        
                    }
                    .alert("SquirrelBear", isPresented: $showAlert) {
                        Button("OK", role: .cancel) {
                        }
                    }
                    message: {
                        Text("You Must Select at Least One Recipient Before Sharing.")
                    }

                }
                .padding()
                
                
                
                
                
                
                
                

                
                
                
                
                
                
                
                
                
                
                
            }
            .navigationTitle("Share with SquirrelBear")
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("IconBackground"))
            .onAppear {
                randomItem = subtitles.randomElement()
            }
            
        }
    }
    func buttonClick() {
        print("click")
    }
}


//            Image("Friend")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 200, height: 200)
//                .foregroundColor(.accentColor)
//
//            Text("SquirrelBear")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//                .padding(.top)
//            HStack{
//
//                Text(randomItem ?? "Run...")
//                    .font(.headline)
//                    .padding(.top, 50)
//            }




#Preview {
    TestView()
}
