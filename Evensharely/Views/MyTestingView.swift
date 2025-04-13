//
//  MyTestingView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI

struct MyTestingView: View {
    var body: some View {
        Button(action: {
            print("hi")
        }) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .padding(.trailing)
        }
    }
}

#Preview {
    MyTestingView()
}
