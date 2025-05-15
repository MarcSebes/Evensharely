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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("IconBackground"))
        .onAppear {
            randomItem = subtitles.randomElement()
        }
    }
}

#Preview {
    TestView()
}
