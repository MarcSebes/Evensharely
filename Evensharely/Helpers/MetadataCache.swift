//
//  MetadataCache.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/9/25.
//

import Foundation
import LinkPresentation

class MetadataCache {
    static let shared = MetadataCache()

    private var cache: [URL: LPLinkMetadata] = [:]

    func get(for url: URL) -> LPLinkMetadata? {
        return cache[url]
    }

    func set(_ metadata: LPLinkMetadata, for url: URL) {
        cache[url] = metadata
    }
}



