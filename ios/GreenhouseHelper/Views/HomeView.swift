import PhotosUI
import SwiftUI
import UIKit

private enum HomeRoute: Hashable {
    case processing
    case history
}

struct HomeView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedResult: AnalysisResult?
    @State private var selectedCachedImageURL: URL?
    @State private var imageForProcessing: UIImage?
    @State private var navigationPath: [HomeRoute] = []
    @State private var showingCamera = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AnimatedWelcomeBackground()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 72)

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Tray viability")
                            .font(AppFont.caption(size: 14, weight: .semibold))
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(AppPalette.lightGreen.opacity(0.95))

                        Text(AppSettings.appName)
                            .font(AppFont.title(size: 42, weight: .bold))
                            .tracking(-0.42)
                            .foregroundStyle(AppPalette.white)
                            .frame(maxWidth: 320, alignment: .leading)

                        Text("Optimize your yield with fast, local tray analysis built for greenhouse workflows.")
                            .font(AppFont.body(size: 19, weight: .medium))
                            .tracking(-0.19)
                            .foregroundStyle(AppPalette.white.opacity(0.86))
                            .frame(maxWidth: 310, alignment: .leading)
                            .lineSpacing(2)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Button("Capture an Image") {
                            showingCamera = true
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        PhotosPicker("Upload an Image", selection: $selectedPhotoItem, matching: .images)
                            .buttonStyle(PrimaryButtonStyle())

                        Button("View History") {
                            showHistory()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(AppPalette.black.opacity(0.34))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppPalette.white.opacity(0.08), lineWidth: 1)
                    )

                    Spacer(minLength: 26)
                    poweredByView
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .processing:
                    if let processingImage = imageForProcessing {
                        ProcessingView(
                            image: processingImage,
                            onCompleted: { result in
                                selectedResult = result
                                selectedCachedImageURL = nil
                            },
                            onFailed: {
                                navigationPath = []
                                imageForProcessing = nil
                            }
                        )
                    }
                case .history:
                    HistoryView { saved in
                        selectedResult = saved.result
                        selectedCachedImageURL = saved.cachedAnnotatedImageURL
                    }
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            selectedResult = nil
                            selectedCachedImageURL = nil
                        }
                    }
                )
            ) {
                if let selectedResult {
                    ResultsView(
                        result: selectedResult,
                        cachedImageURL: selectedCachedImageURL,
                        onTakeAnotherPicture: {
                            goHome()
                        },
                        onViewHistory: {
                            showHistory()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingCamera) {
                CaptureView(image: $selectedImage)
            }
            .onChange(of: selectedImage != nil) { _, hasImage in
                guard hasImage, let selectedImage else { return }
                startProcessing(with: selectedImage)
                self.selectedImage = nil
            }
            .task(id: selectedPhotoItem) {
                guard let selectedPhotoItem else { return }
                if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    startProcessing(with: image)
                }
                self.selectedPhotoItem = nil
            }
        }
    }

    private var poweredByView: some View {
        HStack(spacing: 0) {
            Text("Powered by ")
                .font(AppFont.caption(size: 16, weight: .medium))
                .tracking(-0.16)
                .foregroundStyle(AppPalette.white.opacity(0.88))
            Text("bloomlogic")
                .font(.system(size: 16, weight: .medium, design: .default))
                .tracking(-0.16)
                .italic()
                .foregroundStyle(AppPalette.lightGreen)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func startProcessing(with image: UIImage) {
        imageForProcessing = image
        selectedResult = nil
        selectedCachedImageURL = nil
        navigationPath = [.processing]
    }

    private func showHistory() {
        navigationPath = [.history]
    }

    private func goHome() {
        navigationPath = []
        imageForProcessing = nil
        selectedResult = nil
        selectedCachedImageURL = nil
    }
}

private struct AnimatedWelcomeBackground: View {
    @State private var panProgress: CGFloat = 0
    private let backgroundImage = UIImage(named: "welcome_background")
    private let imageAspectRatio: CGFloat = 1200.0 / 675.0
    private let cycleDuration: Double = 54
    private let extraWidth: CGFloat = 180

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = max(
                geometry.size.width + extraWidth,
                geometry.size.height * imageAspectRatio
            )
            let panDistance = max(1, imageWidth - geometry.size.width)

            ZStack {
                backgroundLayer(size: geometry.size, imageWidth: imageWidth, offsetX: 0)

                backgroundLayer(
                    size: geometry.size,
                    imageWidth: imageWidth,
                    offsetX: -panDistance * panProgress
                )

                LinearGradient(
                    colors: [
                        AppPalette.darkGreen.opacity(0.72),
                        AppPalette.darkGreen.opacity(0.56),
                        AppPalette.black.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.black.opacity(0.18), .clear, AppPalette.black.opacity(0.28)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .clipped()
            .onAppear {
                startAnimationIfNeeded(panDistance: panDistance)
            }
        }
    }

    private func backgroundLayer(size: CGSize, imageWidth: CGFloat, offsetX: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .frame(width: imageWidth, height: size.height)
                    .offset(x: offsetX)
            } else {
                AppPalette.darkGreen
            }
        }
        .frame(width: size.width, height: size.height, alignment: .leading)
        .clipped()
    }

    private func startAnimationIfNeeded(panDistance: CGFloat) {
        guard panDistance > 1, panProgress == 0 else { return }
        withAnimation(.linear(duration: cycleDuration).repeatForever(autoreverses: false)) {
            panProgress = 1
        }
    }
}
