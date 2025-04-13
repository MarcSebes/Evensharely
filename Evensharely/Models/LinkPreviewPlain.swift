//
//  LinkPreviewPlain.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//

import SwiftUI
import LinkPresentation

class CustomLinkView: LPLinkView {
    override var intrinsicContentSize: CGSize {
        CGSize(width:UIScreen.main.bounds.width * 0.9 , height: super.intrinsicContentSize.height)
    }
}

struct LinkPreviewPlain: UIViewRepresentable {
    var previewURL: URL

    func makeUIView(context: Context) -> CustomLinkView {
        let linkView = CustomLinkView(url: previewURL)

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: previewURL) { (metadata, error) in
            guard let metadata = metadata, error == nil else { return }

            DispatchQueue.main.async {
                linkView.metadata = metadata
                linkView.sizeToFit()
            }
        }

        return linkView
    }

    func updateUIView(_ uiView: CustomLinkView, context: Context) {
        // No update needed here
    }
}
