//
//  ScalableLinkPreview.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/16/25.
//

import SwiftUI

struct SwiftUIView: View {
    @State var text = "https://www.instagram.com/p/DJrWSTSRh_e/?utm_source=ig_web_copy_link"
    @State var size: CGFloat = .zero
    @State var size2: CGFloat = .zero
    var body: some View {
        VStack {
//            if let url = checkForFirstUrl(text: text){
//                LinkPreviewView(url: url, width: $size, height: $size2)
//                    .frame(width: size, height: size2, alignment: .leading)
//                    .aspectRatio(contentMode: .fill)
//                    .cornerRadius(15)
//            }
            LinkPreviewPlain(previewURL: URL(string: text)!, width: 100, height: $size2)
        }
    }
}

import LinkPresentation
import UIKit
import SwiftUI

struct LinkPreviewView: UIViewRepresentable {
    let url: URL
    @Binding var width: CGFloat
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> UIView {
        let linkView = CustomLinkView()
        
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metaData, error in
            guard let data = metaData, error == nil else { return }
            DispatchQueue.main.async {
                linkView.metadata = data
                let linksize = linkView.systemLayoutSizeFitting(UIView.layoutFittingExpandedSize)
                let width = linksize.width
                let height = linksize.height
                
                let goal = width*0.7
                
                if width > goal {
                    self.width = goal
                } else {
                    self.width = width
                }
                if height > 300 {
                   self.height = 300
                } else {
                   self.height = height
                }
            }
        }
        return linkView
    }

        func updateUIView(_ uiView: UIView, context: Context) { }
    }
    
    class CustomLinkView: LPLinkView {
        
        init() {
            super.init(frame: .zero)
        }
            
        override var intrinsicContentSize: CGSize {
            return CGSize(width: frame.width, height: frame.height)
        }
    }
    
    func checkForFirstUrl(text: String) -> URL? {
        let types: NSTextCheckingResult.CheckingType = .link
    
        do {
            let detector = try NSDataDetector(types: types.rawValue)
            let matches = detector.matches(in: text, options: .reportCompletion, range: NSMakeRange(0, text.count))
            if let firstMatch = matches.first {
                return firstMatch.url
            }
        } catch {
            print("")
        }
    
        return nil
    }

#Preview {
    SwiftUIView()
}
