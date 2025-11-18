//
//  TestEmptyMessage.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/13/25.
//

import SwiftUI

struct TestView: View {
    @State private var messages = ["Hello, SwiftUI!", "Swipe me!", "Another message"]

    var body: some View {
        VStack {
            ForEach(messages.indices, id: \.self) { index in
                Text(messages[index])
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            messages.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        Button {
                            // Perform some action, e.g., mark as read
                            print("Mark as read: \(messages[index])")
                        } label: {
                            Label("Read", systemImage: "envelope.open.fill")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            // Perform another action, e.g., flag
                            print("Flagged: \(messages[index])")
                        } label: {
                            Label("Flag", systemImage: "flag.fill")
                        }
                    }
            }
        }
    }
}


#Preview {
    TestView()
}
