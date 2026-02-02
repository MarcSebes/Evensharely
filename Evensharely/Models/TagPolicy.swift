//
//  TagPolicy.swift
//  Evensharely
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum TagPolicy {
    // Tags used for internal/system purposes only.
    static let hiddenTags: Set<String> = ["social"]

    static func visibleTags(from tags: [String]) -> [String] {
        tags.filter { !hiddenTags.contains($0) }
    }

    // Preserve hidden/system tags when saving user-visible edits.
    static func mergeHiddenTags(originalTags: [String], editedVisibleTags: [String]) -> [String] {
        let preservedHidden = originalTags.filter { hiddenTags.contains($0) }
        return editedVisibleTags + preservedHidden
    }
}
