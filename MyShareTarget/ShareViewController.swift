//
//  ShareViewController.swift
//  MyShareTarget
//
//  Created by Marc Sebes on 4/7/25.
//
import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("EXTLOG: 🔥 ShareExtensionViewController.viewDidLoad")

        // Grab all item providers, not just the first
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments,
              !providers.isEmpty else {
            NSLog("EXTLOG: ❌ No extension item found")
            return
        }

        // Log each provider's type identifiers
        for provider in providers {
            NSLog("EXTLOG: Provider types: \(provider.registeredTypeIdentifiers)")
        }

        // Prefer a provider that can supply a URL
        let urlProvider = providers.first { prov in
            prov.registeredTypeIdentifiers.contains { id in
                if let ut = UTType(id), ut.conforms(to: .url) {
                    return true
                }
                return false
            }
        }
        // Fallback to plain text
        let textProvider = providers.first { prov in
            prov.registeredTypeIdentifiers.contains { id in
                if let ut = UTType(id), ut.conforms(to: .plainText) {
                    return true
                }
                return false
            }
        }
        // Final fallback to the first provider
        let provider = urlProvider ?? textProvider ?? providers.first!

        // Choose the best UTI to load (prefer URL types)
        let loadID = provider.registeredTypeIdentifiers.first { id in
            if let ut = UTType(id), ut.conforms(to: .url) {
                return true
            }
            return false
        } ?? provider.registeredTypeIdentifiers.first!

        NSLog("EXTLOG: Loading item for type: \(loadID)")

        provider.loadItem(forTypeIdentifier: loadID, options: nil) { item, error in
            if let error = error {
                NSLog("EXTLOG: ⚠️ loadItem error for \(loadID): \(error.localizedDescription)")
                return
            }

            // Extract URL or String...
            var sharedURL: URL?
            if let url = item as? URL {
                sharedURL = url
            } else if let str = item as? String, let url = URL(string: str) {
                sharedURL = url
            } else if let data = item as? Data,
                      let text = String(data: data, encoding: .utf8),
                      let url = URL(string: text) {
                sharedURL = url
            }

            guard let urlToShare = sharedURL else {
                NSLog("EXTLOG: ⚠️ Could not parse URL from item of type \(type(of: item))")
                return
            }

            // Present SwiftUI share view
            DispatchQueue.main.async {
                let contentView = ShareExtensionView(sharedURL: urlToShare) {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                let hosting = UIHostingController(rootView: contentView)
                self.addChild(hosting)
                hosting.view.frame = self.view.bounds
                hosting.view.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(hosting.view)
                hosting.didMove(toParent: self)
                NSLayoutConstraint.activate([
                    hosting.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                    hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                    hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
                ])
            }
        }
    }
}
