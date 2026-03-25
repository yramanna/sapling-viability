import SwiftUI

struct QuickResultView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    let savedAnalysis: SavedAnalysis
    let isBatchMode: Bool
    let sessionName: String?
    let scannedCount: Int?
    let onNextTray: () -> Void
    let onToggleFlag: () -> Void
    let onViewSession: () -> Void
    let onBackHome: () -> Void

    @State private var showingTrayViewer = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                AppPalette.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text(isBatchMode ? "Batch Result" : "Tray Result")
                            .font(AppFont.caption(size: 14, weight: .semibold))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppPalette.lightGreen.opacity(0.96))

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(savedAnalysis.result.trayStats.viabilityPct.rounded()))")
                                .font(AppFont.title(size: 56, weight: .bold))
                                .tracking(-1.0)
                                .foregroundStyle(AppPalette.white)
                            Text("% viable")
                                .font(AppFont.body(size: 18, weight: .medium))
                                .foregroundStyle(AppPalette.white.opacity(0.84))
                        }

                        if let sessionName, isBatchMode {
                            Text("\(sessionName) • \(scannedCount ?? 0) scanned")
                                .font(AppFont.body(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.white.opacity(0.74))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity)
                    .background(AppPalette.darkGreen)

                    VStack(spacing: 14) {
                        Button {
                            showingTrayViewer = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                TrayPreviewImage(
                                    urlString: savedAnalysis.result.artifacts.annotatedImageURL,
                                    localFileURL: savedAnalysis.cachedAnnotatedImageURL
                                )
                                .frame(height: min(max(geometry.size.height * 0.22, 150), 190))
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Inspect tray")
                                        .font(AppFont.body(size: 13, weight: .semibold))
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

                        HStack(spacing: 12) {
                            metricTile(title: "Occupied", value: "\(savedAnalysis.result.trayStats.occupiedCount)")
                            metricTile(title: "Empty", value: "\(savedAnalysis.result.trayStats.emptyCount)")
                            metricTile(title: "Total", value: "\(savedAnalysis.result.trayStats.totalCells)")
                        }

                        VStack(spacing: 12) {
                            if isBatchMode {
                                Button("Next Tray") {
                                    onNextTray()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            } else {
                                Button("Upload Another") {
                                    onBackHome()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }

                            Button(savedAnalysis.isFlagged ? "Unflag Tray" : "Flag Tray") {
                                onToggleFlag()
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button(isBatchMode ? "Session Summary" : "History") {
                                onViewSession()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(AppPalette.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(AppPalette.cardBorder, lineWidth: 1)
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showingTrayViewer) {
            TrayLightboxView(
                urlString: savedAnalysis.result.artifacts.annotatedImageURL,
                localFileURL: savedAnalysis.cachedAnnotatedImageURL
            ) {
                showingTrayViewer = false
            }
        }
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

struct ResultsView: View {
    let result: AnalysisResult
    let cachedImageURL: URL?
    let allowsSystemBackNavigation: Bool
    let primaryButtonTitle: String?
    let onPrimaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let onSecondaryAction: (() -> Void)?
    let tertiaryButtonTitle: String?
    let onTertiaryAction: (() -> Void)?
    let destructiveButtonTitle: String?
    let onDestructiveAction: (() -> Void)?

    @State private var showingTrayViewer = false
    @State private var showingDeleteConfirmation = false

    init(
        result: AnalysisResult,
        cachedImageURL: URL? = nil,
        allowsSystemBackNavigation: Bool = true,
        primaryButtonTitle: String? = nil,
        onPrimaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        tertiaryButtonTitle: String? = nil,
        onTertiaryAction: (() -> Void)? = nil,
        destructiveButtonTitle: String? = nil,
        onDestructiveAction: (() -> Void)? = nil
    ) {
        self.result = result
        self.cachedImageURL = cachedImageURL
        self.allowsSystemBackNavigation = allowsSystemBackNavigation
        self.primaryButtonTitle = primaryButtonTitle
        self.onPrimaryAction = onPrimaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.onSecondaryAction = onSecondaryAction
        self.tertiaryButtonTitle = tertiaryButtonTitle
        self.onTertiaryAction = onTertiaryAction
        self.destructiveButtonTitle = destructiveButtonTitle
        self.onDestructiveAction = onDestructiveAction
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
                                    .frame(height: min(max(geometry.size.height * 0.22, 150), 190))
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Inspect tray")
                                        .font(AppFont.body(size: 13, weight: .semibold))
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

                        HStack(spacing: 12) {
                            metricTile(title: "Occupied", value: "\(result.trayStats.occupiedCount)")
                            metricTile(title: "Empty", value: "\(result.trayStats.emptyCount)")
                            metricTile(title: "Total", value: "\(result.trayStats.totalCells)")
                        }

                        if primaryButtonTitle != nil || secondaryButtonTitle != nil || tertiaryButtonTitle != nil || destructiveButtonTitle != nil {
                            VStack(spacing: 12) {
                                if let primaryButtonTitle, let onPrimaryAction {
                                    Button(primaryButtonTitle) {
                                        onPrimaryAction()
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }

                                if let secondaryButtonTitle, let onSecondaryAction {
                                    Button(secondaryButtonTitle) {
                                        onSecondaryAction()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }

                                if let tertiaryButtonTitle, let onTertiaryAction {
                                    Button(tertiaryButtonTitle) {
                                        onTertiaryAction()
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }

                                if let destructiveButtonTitle, onDestructiveAction != nil {
                                    Button {
                                        showingDeleteConfirmation = true
                                    } label: {
                                        destructiveActionRow(title: destructiveButtonTitle)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(AppPalette.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(AppPalette.cardBorder, lineWidth: 1)
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(allowsSystemBackNavigation ? .visible : .hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(!allowsSystemBackNavigation)
        .alert("Delete this tray from history?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDestructiveAction?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved result and cached tray image from this device.")
        }
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
            Text("Tray Result")
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
                    .foregroundStyle(AppPalette.white.opacity(0.84))
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Inspect the tray preview to review labeled cells in detail.")
                .font(AppFont.body(size: 14, weight: .medium))
                .tracking(-0.14)
                .foregroundStyle(AppPalette.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(AppPalette.darkGreen)
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

    @ViewBuilder
    private func destructiveActionRow(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))

            Text(title)
                .font(AppFont.body(size: 15, weight: .semibold))
                .tracking(-0.14)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.red.opacity(0.82))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.12), lineWidth: 1)
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
