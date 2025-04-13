//
//  SharedLinksView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/11/25.
//

import SwiftUI

enum SharedLinkViewMode: String, CaseIterable {
    case inbox = "Shared With Me"
    case sent = "Shared By Me"
}

struct SharedLinksView: View {
    @State private var viewMode: SharedLinkViewMode = .inbox

    var body: some View {
        NavigationView {
            VStack {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(SharedLinkViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Divider()

                switch viewMode {
                case .inbox:
                    ContentView()
                case .sent:
                    SentView()
                }
            }
            .navigationBarTitle("Messages", displayMode: .inline)
        }
    }
}

