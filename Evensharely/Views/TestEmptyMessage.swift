//
//  TestEmptyMessage.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI

struct TestEmptyMessage: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("You Don't Have Any Favorites Yet!")
                .font(.headline)
            Text("SquirrelBear can be your favorite!")
                .font(.title2)
                .foregroundColor(.secondary)
            Image("Friend")
                .resizable()
                .frame(width: 300, height: 300)
            
        }
    }
}

#Preview {
    TestEmptyMessage()
}
