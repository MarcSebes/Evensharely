//
//  ShareViewController.swift
//  MyShareTarget
//
//  Created by Marc Sebes on 4/7/25.
//

import UIKit
import SwiftUI
import Social

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        print("🚀 ShareViewController loaded successfully")

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            print("❌ No extension item found")
            return
        }

        itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { (data, error) in
            if let error = error {
                print("❌ Error loading URL: \(error.localizedDescription)")
                return
            }

            guard let url = data as? URL else {
                print("❌ Could not extract URL from shared item")
                return
            }

            DispatchQueue.main.async {
                let contentView = ShareExtensionView(sharedURL: url) {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }

                let hostingController = UIHostingController(rootView: contentView)
                self.addChild(hostingController)
                hostingController.view.frame = self.view.bounds
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(hostingController.view)
                hostingController.didMove(toParent: self)

                NSLayoutConstraint.activate([
                    hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                    hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
                ])
            }
        }
    }
}

