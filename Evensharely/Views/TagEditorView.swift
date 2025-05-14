//
//  TagEditorView.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/18/25.
//

import SwiftUI

struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draftTags: String
    private let initialTags: [String]
    private let onSave: ([String]) -> Void

    init(sharedLink: SharedLink, onSave: @escaping ([String]) -> Void) {
        self.initialTags = sharedLink.tags
        _draftTags = State(initialValue: sharedLink.tags.joined(separator: ", "))
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Tags (comma‑separated)") {
                    TextField("e.g. dogs, animals", text: $draftTags)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Edit Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Split & trim into an array of non‑empty tags
                        let tags = draftTags
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(tags)
                        dismiss()
                    }
                }
            }
        }
    }
}
