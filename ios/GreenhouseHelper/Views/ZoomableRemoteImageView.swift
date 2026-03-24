import SwiftUI
import UIKit

struct ZoomableRemoteImageView: View {
    let urlString: String?
    let localFileURL: URL?
    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let localFileURL,
                   let image = UIImage(contentsOfFile: localFileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    AsyncImage(url: URL(string: urlString ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(steadyScale * value, 1), 4)
                    }
                    .onEnded { _ in
                        steadyScale = scale
                        if scale <= 1.01 {
                            withAnimation(.spring()) {
                                offset = .zero
                                steadyOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: steadyOffset.width + value.translation.width,
                            height: steadyOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard scale > 1 else {
                            offset = .zero
                            steadyOffset = .zero
                            return
                        }
                        steadyOffset = offset
                    }
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
