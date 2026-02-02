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
        let visibleTags = TagPolicy.visibleTags(from: sharedLink.tags)
        _draftTags = State(initialValue: visibleTags.joined(separator: ", "))
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
                        let visibleTags = draftTags
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        let tags = TagPolicy.mergeHiddenTags(
                            originalTags: initialTags,
                            editedVisibleTags: visibleTags
                        )
                        onSave(tags)
                        dismiss()
                    }
                }
            }
        }
    }
}
