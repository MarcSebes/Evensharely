//
//  LinkPreviewPlain.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/10/25.
//

import SwiftUI
import LinkPresentation

struct LinkPreviewPlain: UIViewRepresentable {
    var previewURL: URL
    var width: CGFloat
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let linkView = LPLinkView(url: previewURL)
        linkView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(linkView)
        
        let widthConstraint = linkView.widthAnchor.constraint(equalToConstant: width)
            widthConstraint.priority = .required
            widthConstraint.isActive = true

        NSLayoutConstraint.activate([
            linkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            linkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            linkView.topAnchor.constraint(equalTo: container.topAnchor),
            linkView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: previewURL) { metadata, error in
            guard let metadata = metadata, error == nil else { return }

            DispatchQueue.main.async {
                linkView.metadata = metadata

                // Wait a little longer to allow layout rendering
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    container.setNeedsLayout()
                    container.layoutIfNeeded()

          
                    let fittedSize = container.systemLayoutSizeFitting(
                        CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
                    )

                    if fittedSize.height > 0 {
                        context.coordinator.height.wrappedValue = fittedSize.height
                    }
                }
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator {
        var height: Binding<CGFloat>

        init(height: Binding<CGFloat>) {
            self.height = height
        }
    }
}


