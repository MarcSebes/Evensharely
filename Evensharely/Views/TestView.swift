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
                                // Optional: Add any code to run when the button is tapped
                            }
                        }
                        message: {
                            Text("You Must Select at Least One Recipient Before Sharing.")
                        }
            
            
            
            
            
            
            
            
            
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("IconBackground"))
        .onAppear {
            randomItem = subtitles.randomElement()
        }
    }
    func buttonClick() {
        print("click")
    }
}

#Preview {
    TestView()
}
