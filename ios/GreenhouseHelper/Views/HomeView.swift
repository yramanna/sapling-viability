import PhotosUI
import SwiftUI
import UIKit

private enum HomeRoute: Hashable {
    case batchSetup
    case singleTray
    case quickResult
    case uploadTrayDetail
    case history
    case sessionSummary(String)
    case sessionDetail(String)
    case trayDetail(String)
}

private enum CaptureMode: String, Identifiable {
    case single
    case batch

    var id: String { rawValue }
}

private enum ProcessingMode {
    case single
    case batch
}

private struct ActiveBatchSession {
    let id: String
    let startedAt: Date
    var name: String
    var nextTrayNumber: Int
    var scannedCount: Int

    var displayName: String {
        if !name.isEmpty {
            return name
        }
        return startedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct HomeView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uploadPickerID = UUID()
    @State private var navigationPath: [HomeRoute] = []
    @State private var activeCaptureMode: CaptureMode?
    @State private var imageForProcessing: UIImage?
    @State private var processingMode: ProcessingMode?
    @State private var isShowingProcessing = false
    @State private var currentSession: ActiveBatchSession?
    @State private var currentPresentedAnalysis: SavedAnalysis?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AnchoredActionScreen(
                background: {
                    AnimatedWelcomeBackground()
                },
                header: {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Greenhouse workflow")
                            .font(AppFont.caption(size: 14, weight: .semibold))
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(AppPalette.lightGreen.opacity(0.95))

                        Text(AppSettings.appName)
                            .font(AppFont.title(size: 42, weight: .bold))
                            .tracking(-0.42)
                            .foregroundStyle(AppPalette.white)
                            .frame(maxWidth: 320, alignment: .leading)

                        Text("Scan trays in batches, review viability fast, and keep work moving across the greenhouse.")
                            .font(AppFont.body(size: 19, weight: .medium))
                            .tracking(-0.19)
                            .foregroundStyle(AppPalette.white.opacity(0.86))
                            .frame(maxWidth: 320, alignment: .leading)
                            .lineSpacing(2)
                    }
                },
                actions: {
                    VStack(spacing: 14) {
                        Button("Scan Trays in Batch") {
                            navigationPath = [.batchSetup]
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Scan One Tray") {
                            navigationPath = [.singleTray]
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("History") {
                            navigationPath = [.history]
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
                },
                footer: {
                    poweredByView
                },
                headerTopPadding: 100,
                actionTopRatio: ActionAnchorMetrics.cardTopRatio,
                footerBottomPadding: 28
            )
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .batchSetup:
                    BatchSetupView(
                        onStart: { name, startingTrayNumber in
                            startBatchSession(name: name, startingTrayNumber: startingTrayNumber)
                        },
                        onSkip: {
                            startBatchSession(name: "", startingTrayNumber: 1)
                        }
                    )
                case .singleTray:
                    SingleTrayEntryView(
                        uploadPickerID: uploadPickerID,
                        selectedPhotoItem: $selectedPhotoItem,
                        onUploadedImage: { image in
                            startProcessing(with: image, mode: .single)
                        },
                        onCapture: {
                            presentCamera(.single)
                        }
                    )
                case .quickResult:
                    if let saved = currentPresentedAnalysis {
                        let isCurrentSessionTray = saved.sessionID != nil && saved.sessionID == currentSession?.id
                        QuickResultView(
                            savedAnalysis: saved,
                            isBatchMode: isCurrentSessionTray,
                            sessionName: currentSession?.displayName,
                            scannedCount: currentSession?.scannedCount,
                            onNextTray: {
                                navigationPath = []
                                presentCamera(.batch)
                            },
                            onToggleFlag: {
                                historyStore.setFlagged(!saved.isFlagged, for: saved.id)
                            },
                            onViewSession: {
                                if let sessionID = saved.sessionID {
                                    navigationPath.append(.sessionSummary(sessionID))
                                } else {
                                    navigationPath.append(.history)
                                }
                            },
                            onBackHome: {
                                goHome()
                            }
                        )
                    }
                case .uploadTrayDetail:
                    if let saved = currentPresentedAnalysis {
                        ResultsView(
                            result: saved.result,
                            cachedImageURL: saved.cachedAnnotatedImageURL,
                            allowsSystemBackNavigation: false,
                            primaryButtonTitle: "Scan More",
                            onPrimaryAction: {
                                navigationPath = [.singleTray]
                                selectedPhotoItem = nil
                                uploadPickerID = UUID()
                            },
                            secondaryButtonTitle: "History",
                            onSecondaryAction: {
                                navigationPath = [.history]
                            },
                            tertiaryButtonTitle: "Finish",
                            onTertiaryAction: {
                                goHome()
                            }
                        )
                    }
                case .history:
                    HistoryView(
                        onSessionSelected: { session in
                            navigationPath.append(.sessionDetail(session.id))
                        },
                        onSingleSelected: { saved in
                            navigationPath.append(.trayDetail(saved.id))
                        }
                    )
                case .sessionSummary(let sessionID):
                    if let session = savedSession(id: sessionID) {
                        SessionSummaryView(
                            session: session,
                            isCurrentSession: currentSession?.id == sessionID,
                            onContinueScanning: {
                                navigationPath = []
                                presentCamera(.batch)
                            },
                            onReviewSession: {
                                navigationPath.append(.sessionDetail(sessionID))
                            },
                            onEndSession: {
                                currentSession = nil
                                goHome()
                            }
                        )
                    }
                case .sessionDetail(let sessionID):
                    if let session = savedSession(id: sessionID) {
                        SessionDetailView(session: session) { saved in
                            navigationPath.append(.trayDetail(saved.id))
                        }
                    }
                case .trayDetail(let analysisID):
                    if let saved = presentedAnalysis(id: analysisID) {
                        let isCurrentSessionTray = saved.sessionID != nil && saved.sessionID == currentSession?.id
                        ResultsView(
                            result: saved.result,
                            cachedImageURL: saved.cachedAnnotatedImageURL,
                            primaryButtonTitle: isCurrentSessionTray ? "Scan Next Tray" : nil,
                            onPrimaryAction: isCurrentSessionTray ? {
                                navigationPath = []
                                presentCamera(.batch)
                            } : nil,
                            secondaryButtonTitle: isCurrentSessionTray ? "Back to session" : nil,
                            onSecondaryAction: isCurrentSessionTray ? {
                                if let sessionID = saved.sessionID {
                                    navigationPath = [.sessionSummary(sessionID)]
                                }
                            } : nil
                        )
                    }
                }
            }
            .fullScreenCover(item: $activeCaptureMode) { mode in
                CaptureView(
                    headerTitle: mode == .batch ? "SESSION" : "CAPTURE",
                    headerSubtitle: "HOLD PARALLEL TO TRAY",
                    secondaryActionTitle: nil,
                    onCaptured: { captured in
                        startProcessing(with: captured, mode: mode == .batch ? .batch : .single)
                        activeCaptureMode = nil
                    },
                    onClose: {
                        activeCaptureMode = nil
                    },
                    onSecondaryAction: nil
                )
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { isShowingProcessing && imageForProcessing != nil },
                    set: { isPresented in
                        if !isPresented {
                            isShowingProcessing = false
                        }
                    }
                )
            ) {
                if let processingImage = imageForProcessing {
                    ProcessingView(
                        image: processingImage,
                        isBatchMode: processingMode == .batch,
                        sessionID: currentSession?.id,
                        sessionName: currentSession?.displayName,
                        trayNumber: processingMode == .batch ? currentSession?.nextTrayNumber : nil,
                        onCompleted: { saved in
                            handleCompletedScan(saved)
                        },
                        onFailed: {
                            if processingMode == .batch {
                                imageForProcessing = nil
                                processingMode = nil
                                isShowingProcessing = false
                                navigationPath = []
                                presentCamera(.batch)
                            } else {
                                handleProcessingFailure()
                            }
                        },
                        onRetake: processingMode == .batch ? {
                            navigationPath = []
                            imageForProcessing = nil
                            processingMode = nil
                            isShowingProcessing = false
                            presentCamera(.batch)
                        } : nil
                    )
                }
            }
        }
    }

    private var poweredByView: some View {
        HStack(spacing: 0) {
            Text("Powered by ")
                .font(AppFont.caption(size: 15, weight: .medium))
                .tracking(-0.14)
                .foregroundStyle(AppPalette.white.opacity(0.78))
            Text("bloomlogic")
                .font(.system(size: 15, weight: .medium, design: .default))
                .tracking(-0.14)
                .italic()
                .foregroundStyle(AppPalette.lightGreen)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func startBatchSession(name: String, startingTrayNumber: Int) {
        currentSession = ActiveBatchSession(
            id: UUID().uuidString,
            startedAt: Date(),
            name: name,
            nextTrayNumber: max(1, startingTrayNumber),
            scannedCount: 0
        )
        navigationPath = []
        presentCamera(.batch)
    }

    private func startProcessing(with image: UIImage, mode: ProcessingMode) {
        imageForProcessing = image
        processingMode = mode
        isShowingProcessing = true
    }

    private func handleCompletedScan(_ saved: SavedAnalysis) {
        currentPresentedAnalysis = saved

        if saved.sessionID == currentSession?.id {
            currentSession?.scannedCount += 1
            if let trayNumber = saved.trayNumber {
                currentSession?.nextTrayNumber = trayNumber + 1
            } else {
                currentSession?.nextTrayNumber += 1
            }
        }

        imageForProcessing = nil
        processingMode = nil
        isShowingProcessing = false
        if saved.sessionID == nil {
            navigationPath = [.uploadTrayDetail]
        } else {
            navigationPath = [.quickResult]
        }
    }

    private func handleProcessingFailure() {
        imageForProcessing = nil
        processingMode = nil
        isShowingProcessing = false
        currentPresentedAnalysis = nil
        navigationPath = []
    }

    private func goHome() {
        navigationPath = []
        imageForProcessing = nil
        processingMode = nil
        isShowingProcessing = false
        activeCaptureMode = nil
        currentPresentedAnalysis = nil
    }

    private func presentCamera(_ mode: CaptureMode) {
        DispatchQueue.main.async {
            activeCaptureMode = mode
        }
    }

    private func savedAnalysis(id: String) -> SavedAnalysis? {
        historyStore.savedAnalyses.first(where: { $0.id == id })
    }

    private func presentedAnalysis(id: String) -> SavedAnalysis? {
        if let currentPresentedAnalysis, currentPresentedAnalysis.id == id {
            return currentPresentedAnalysis
        }
        return savedAnalysis(id: id)
    }

    private func savedSession(id: String) -> SavedSession? {
        historyStore.savedSessions.first(where: { $0.id == id })
    }
}

private enum ActionAnchorMetrics {
    static let cardTopRatio: CGFloat = 0.54
}

private struct AnchoredActionScreen<Background: View, Header: View, Actions: View, Footer: View>: View {
    let background: () -> Background
    let header: () -> Header
    let actions: () -> Actions
    let footer: () -> Footer
    let headerTopPadding: CGFloat
    let actionTopRatio: CGFloat
    let footerBottomPadding: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                background()
                    .ignoresSafeArea()

                header()
                    .padding(.horizontal, 24)
                    .padding(.top, headerTopPadding)

                actions()
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, geometry.size.height * actionTopRatio)

                VStack {
                    Spacer()
                    footer()
                        .padding(.horizontal, 24)
                        .padding(.bottom, footerBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct BatchSetupView: View {
    let onStart: (String, Int) -> Void
    let onSkip: () -> Void

    @State private var sessionName = ""
    @State private var startingTrayNumber = "1"

    var body: some View {
        AnchoredActionScreen(
            background: {
                ZStack {
                    AppPalette.surface

                    LinearGradient(
                        colors: [
                            AppPalette.lightGreen.opacity(0.14),
                            AppPalette.surface.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            },
            header: {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BATCH MODE")
                            .font(AppFont.caption(size: 13, weight: .semibold))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppPalette.lightGreen.opacity(0.95))

                        Text("Batch Scan Setup")
                            .font(AppFont.title(size: 34, weight: .bold))
                            .tracking(-0.34)
                            .foregroundStyle(AppPalette.darkGreen)

                        Text("Create a light session context before scanning a long run of trays.")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .tracking(-0.16)
                            .foregroundStyle(AppPalette.mutedText)
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session name")
                                .font(AppFont.caption(size: 13, weight: .semibold))
                                .tracking(1.1)
                                .textCase(.uppercase)
                                .foregroundStyle(AppPalette.mutedText)

                            TextField("Zone A Morning", text: $sessionName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppPalette.darkGreen)
                                .tint(AppPalette.darkGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppPalette.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AppPalette.cardBorder, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Starting tray number")
                                .font(AppFont.caption(size: 13, weight: .semibold))
                                .tracking(1.1)
                                .textCase(.uppercase)
                                .foregroundStyle(AppPalette.mutedText)

                            TextField("1", text: $startingTrayNumber)
                                .keyboardType(.numberPad)
                                .foregroundStyle(AppPalette.darkGreen)
                                .tint(AppPalette.darkGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppPalette.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AppPalette.cardBorder, lineWidth: 1)
                                )
                        }
                    }

                    Text("For scanning long tray runs with minimal interruptions.")
                        .font(AppFont.caption(size: 14, weight: .medium))
                        .tracking(-0.12)
                        .foregroundStyle(AppPalette.mutedText.opacity(0.82))
                }
            },
            actions: {
                VStack(spacing: 14) {
                    Button("Begin Batch Scan") {
                        onStart(sessionName.trimmingCharacters(in: .whitespacesAndNewlines), Int(startingTrayNumber) ?? 1)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Scan Without Setup") {
                        onSkip()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppPalette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppPalette.cardBorder, lineWidth: 1)
                )
                .shadow(
                    color: AppPalette.darkGreen.opacity(0.08),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            },
            footer: {
                EmptyView()
            },
            headerTopPadding: 8,
            actionTopRatio: ActionAnchorMetrics.cardTopRatio,
            footerBottomPadding: 0
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SingleTrayEntryView: View {
    let uploadPickerID: UUID
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onUploadedImage: (UIImage) -> Void
    let onCapture: () -> Void

    var body: some View {
        AnchoredActionScreen(
            background: {
                ZStack {
                    AppPalette.surface

                    LinearGradient(
                        colors: [
                            AppPalette.lightGreen.opacity(0.14),
                            AppPalette.surface.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            },
            header: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ONE-OFF MODE")
                        .font(AppFont.caption(size: 13, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.lightGreen.opacity(0.95))

                    Text("One Tray Scan")
                        .font(AppFont.title(size: 34, weight: .bold))
                        .tracking(-0.34)
                        .foregroundStyle(AppPalette.darkGreen)

                    Text("Capture or upload one tray when you need a closer review outside the batch workflow.")
                        .font(AppFont.body(size: 16, weight: .medium))
                        .tracking(-0.16)
                        .foregroundStyle(AppPalette.mutedText)
                        .frame(maxWidth: 320, alignment: .leading)

                    Text("Best for one-off review and spot checks.")
                        .font(AppFont.caption(size: 14, weight: .medium))
                        .tracking(-0.12)
                        .foregroundStyle(AppPalette.mutedText.opacity(0.82))
                }
            },
            actions: {
                VStack(spacing: 14) {
                    Button("Capture Image") {
                        onCapture()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    PhotosPicker("Upload Image", selection: $selectedPhotoItem, matching: .images)
                        .id(uploadPickerID)
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppPalette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppPalette.cardBorder, lineWidth: 1)
                )
                .shadow(
                    color: AppPalette.darkGreen.opacity(0.08),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            },
            footer: {
                EmptyView()
            },
            headerTopPadding: 4,
            actionTopRatio: ActionAnchorMetrics.cardTopRatio,
            footerBottomPadding: 0
        )
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                onUploadedImage(image)
            }
            self.selectedPhotoItem = nil
        }
    }
}

private struct SessionSummaryView: View {
    let session: SavedSession
    let isCurrentSession: Bool
    let onContinueScanning: () -> Void
    let onReviewSession: () -> Void
    let onEndSession: () -> Void

    var body: some View {
        ZStack {
            AppPalette.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Summary")
                            .font(AppFont.title(size: 34, weight: .bold))
                            .tracking(-0.34)
                            .foregroundStyle(AppPalette.darkGreen)

                        Text(session.name)
                            .font(AppFont.body(size: 17, weight: .medium))
                            .foregroundStyle(AppPalette.mutedText)
                    }

                    HStack(spacing: 12) {
                        summaryCard(title: "Trays", value: "\(session.trayCount)")
                        summaryCard(title: "Avg Viability", value: "\(Int(session.averageViability.rounded()))%")
                        summaryCard(title: "Flagged", value: "\(session.flaggedCount)")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent scans")
                            .font(AppFont.caption(size: 13, weight: .semibold))
                            .tracking(1.1)
                            .textCase(.uppercase)
                            .foregroundStyle(AppPalette.mutedText)

                        ForEach(session.analyses.prefix(4)) { saved in
                            HStack {
                                Text(saved.trayLabel)
                                    .font(AppFont.body(size: 16, weight: .semibold))
                                    .foregroundStyle(AppPalette.darkGreen)
                                Spacer()
                                Text("\(Int(saved.result.trayStats.viabilityPct.rounded()))%")
                                    .font(AppFont.body(size: 16, weight: .semibold))
                                    .foregroundStyle(AppPalette.darkGreen)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppPalette.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppPalette.cardBorder, lineWidth: 1)
                            )
                        }
                    }

                }
                .padding(24)
                .padding(.bottom, 220)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if isCurrentSession {
                    Button("Continue Scanning") {
                        onContinueScanning()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("Review Session") {
                    onReviewSession()
                }
                .modifier(SessionReviewButtonStyle(isCurrentSession: isCurrentSession))

                if isCurrentSession {
                    Button("End Session") {
                        onEndSession()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppPalette.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 68)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.caption(size: 12, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.mutedText)
            Text(value)
                .font(AppFont.title(size: 28, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppPalette.darkGreen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.cardBorder, lineWidth: 1)
        )
    }
}

private struct SessionReviewButtonStyle: ViewModifier {
    let isCurrentSession: Bool

    func body(content: Content) -> some View {
        if isCurrentSession {
            content.buttonStyle(SecondaryButtonStyle())
        } else {
            content.buttonStyle(PrimaryButtonStyle())
        }
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
