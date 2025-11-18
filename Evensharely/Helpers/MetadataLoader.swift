//
//  MetadataLoader.swift
//  Evensharely
//
//  Created by Marc Sebes on 9/18/25.
//

// MetadataLoader.swift
import SwiftUI
import LinkPresentation

@MainActor
final class MetadataLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    private var loaded = false

    func loadIfNeeded(url: URL) async {
        guard !loaded else { return }
        loaded = true
        do {
            let meta = try await LPMetadataCache.shared.metadata(for: url)
            self.metadata = meta
        } catch {
            // noop; keep basic UI
        }
    }
}

