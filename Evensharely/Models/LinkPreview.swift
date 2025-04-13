//
//  LinkPreview.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/7/25.
//

import SwiftUI
import LinkPresentation

struct LinkPreview: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
       let linkView = LPLinkView(metadata: metadata)
        /*
        DispatchQueue.main.async {
            linkView.metadata = metadata
            linkView.sizeToFit()
        }
         */
        return linkView
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}


