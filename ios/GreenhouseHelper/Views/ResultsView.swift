import SwiftUI

struct ResultsView: View {
    let result: AnalysisResult
    let cachedImageURL: URL?
    let onTakeAnotherPicture: () -> Void
    let onViewHistory: () -> Void

    @State private var showingTrayViewer = false

    init(
        result: AnalysisResult,
        cachedImageURL: URL? = nil,
        onTakeAnotherPicture: @escaping () -> Void = {},
        onViewHistory: @escaping () -> Void = {}
    ) {
        self.result = result
        self.cachedImageURL = cachedImageURL
        self.onTakeAnotherPicture = onTakeAnotherPicture
        self.onViewHistory = onViewHistory
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                AppPalette.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    statsHeader

                    VStack(spacing: 14) {
                        Button {
                            showingTrayViewer = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                TrayPreviewImage(urlString: result.artifacts.annotatedImageURL, localFileURL: cachedImageURL)
                                    .frame(height: min(max(geometry.size.height * 0.26, 170), 215))
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Tap to inspect")
                                        .font(AppFont.body(size: 13, weight: .semibold))
                                        .tracking(-0.13)
                                }
                                .foregroundStyle(AppPalette.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(AppPalette.black.opacity(0.78))
                                .clipShape(Capsule())
                                .padding(14)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(AppPalette.black)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(AppPalette.cardBorder.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: AppPalette.black.opacity(0.12), radius: 18, x: 0, y: 8)

                        HStack(spacing: 12) {
                            metricTile(title: "Occupied", value: "\(result.trayStats.occupiedCount)")
                            metricTile(title: "Empty", value: "\(result.trayStats.emptyCount)")
                            metricTile(title: "Total", value: "\(result.trayStats.totalCells)")
                        }

                        VStack(spacing: 12) {
                            Button("Take another picture") {
                                onTakeAnotherPicture()
                            }
                            .buttonStyle(PrimaryButtonStyle())

                        Button("View history") {
                            onViewHistory()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.top, 2)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showingTrayViewer) {
            TrayLightboxView(
                urlString: result.artifacts.annotatedImageURL,
                localFileURL: cachedImageURL
            ) {
                showingTrayViewer = false
            }
        }
    }

    private var statsHeader: some View {
        VStack(spacing: 10) {
            Text("Tray Statistics")
                .font(AppFont.caption(size: 14, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.lightGreen.opacity(0.96))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(result.trayStats.viabilityPct.rounded()))")
                    .font(AppFont.title(size: 54, weight: .bold))
                    .tracking(-1.0)
                    .foregroundStyle(AppPalette.white)
                Text("% viable")
                    .font(AppFont.body(size: 18, weight: .medium))
                    .tracking(-0.18)
                    .foregroundStyle(AppPalette.white.opacity(0.84))
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Inspect the tray preview to review labeled cells in detail.")
                .font(AppFont.body(size: 14, weight: .medium))
                .tracking(-0.14)
                .foregroundStyle(AppPalette.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(AppPalette.darkGreen)
        .safeAreaPadding(.top, 0)
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.caption(size: 12, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.mutedText.opacity(0.75))
            Text(value)
                .font(AppFont.title(size: 28, weight: .bold))
                .tracking(-0.45)
                .foregroundStyle(AppPalette.darkGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.cardBorder.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct TrayPreviewImage: View {
    let urlString: String?
    let localFileURL: URL?

    var body: some View {
        Group {
            if let localFileURL,
               let image = UIImage(contentsOfFile: localFileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: URL(string: urlString ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        AppPalette.black
                        ProgressView()
                            .tint(AppPalette.white)
                    }
                }
            }
        }
    }
}

private struct TrayLightboxView: View {
    let urlString: String?
    let localFileURL: URL?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.black, AppPalette.darkGreen.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 22)

                ZoomableRemoteImageView(urlString: urlString, localFileURL: localFileURL)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                Text("Pinch to zoom and drag to inspect the tray.")
                    .font(AppFont.body(size: 14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(AppPalette.white.opacity(0.78))

                Button("Close") {
                    onClose()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 20)
            }
        }
    }
}
