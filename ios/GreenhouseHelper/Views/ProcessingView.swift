import SwiftUI
import UIKit

struct ProcessingView: View {
    @EnvironmentObject private var analysisViewModel: AnalysisViewModel
    @EnvironmentObject private var historyStore: HistoryStore

    let image: UIImage
    let isBatchMode: Bool
    let sessionID: String?
    let sessionName: String?
    let trayNumber: Int?
    let onCompleted: (SavedAnalysis) -> Void
    let onFailed: () -> Void
    let onRetake: (() -> Void)?

    @State private var errorMessage: String?
    @State private var attemptID = UUID()
    @State private var statusIndex = 0

    private let noTrayMessage = "No tray was found in this image. Please retake the photo with the full tray clearly visible."
    private let statuses = [
        "Detecting tray",
        "Extracting cells",
        "Calculating viability",
        "Preparing result"
    ]

    var body: some View {
        ZStack {
            AppPalette.surface.ignoresSafeArea()
            ProcessingBackgroundMotif()
                .ignoresSafeArea()

            Group {
                if let errorMessage {
                    errorState(message: errorMessage)
                } else {
                    loadingState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task(id: attemptID) {
            guard errorMessage == nil else { return }
            if let result = await analysisViewModel.analyze(
                image: image,
                historyStore: historyStore,
                sessionID: sessionID,
                sessionName: sessionName,
                trayNumber: trayNumber
            ) {
                onCompleted(result)
            } else {
                errorMessage = analysisViewModel.errorMessage ?? "We couldn't complete the scan. Please try again."
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                TrayCellLoader(stageIndex: statusIndex)

                VStack(spacing: 12) {
                    Text("Analysing tray")
                        .font(AppFont.title(size: 34, weight: .bold))
                        .tracking(-0.34)
                        .foregroundStyle(AppPalette.darkGreen)

                    Text(statuses[statusIndex])
                        .font(AppFont.body(size: 15, weight: .medium))
                        .tracking(-0.15)
                        .foregroundStyle(AppPalette.darkGreen.opacity(0.9))
                        .id(statusIndex)
                        .transition(.opacity)
                }
            }

            Spacer()

            HStack(spacing: 0) {
                Text("Powered by ")
                    .font(AppFont.caption(size: 15, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(AppPalette.mutedText.opacity(0.86))
                Text("bloomlogic")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .tracking(-0.14)
                    .italic()
                    .foregroundStyle(AppPalette.lightGreen)
            }
            .padding(.bottom, 22)
        }
        .task {
            while errorMessage == nil {
                try? await Task.sleep(for: .seconds(1.0))
                guard errorMessage == nil else { break }
                withAnimation(.easeInOut(duration: 0.25)) {
                    statusIndex = (statusIndex + 1) % statuses.count
                }
            }
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppPalette.darkGreen.opacity(0.05))
                    .frame(width: 150, height: 150)
                Circle()
                    .stroke(AppPalette.darkGreen.opacity(0.1), lineWidth: 1)
                    .frame(width: 150, height: 150)
                Image(systemName: isNoTrayMessage(message) ? "viewfinder" : "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(AppPalette.darkGreen)
            }

            VStack(spacing: 12) {
                Text(isNoTrayMessage(message) ? "Tray not detected" : "Scan couldn't complete")
                    .font(AppFont.title(size: 32, weight: .bold))
                    .tracking(-0.32)
                    .foregroundStyle(AppPalette.darkGreen)

                Text(message)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .tracking(-0.15)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.darkGreen.opacity(0.82))
                    .padding(.horizontal, 26)
                    .frame(maxWidth: 360)
            }

            VStack(spacing: 12) {
                Button(isBatchMode ? "Retake" : "Try again") {
                    errorMessage = nil
                    if isBatchMode, let onRetake {
                        onRetake()
                    } else {
                        attemptID = UUID()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(isBatchMode ? "Skip tray" : "Back to home") {
                    errorMessage = nil
                    onFailed()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func isNoTrayMessage(_ message: String) -> Bool {
        message == noTrayMessage
    }
}

private struct TrayCellLoader: View {
    let stageIndex: Int

    @State private var animationStep = 0
    private let columns = Array(repeating: GridItem(.fixed(18), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellColor(for: index))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppPalette.darkGreen.opacity(0.08), lineWidth: 1)
                    )
                    .scaleEffect(isLeadingCell(index) ? 1.08 : 1.0)
                    .shadow(
                        color: isLeadingCell(index) ? AppPalette.lightGreen.opacity(0.35) : .clear,
                        radius: isLeadingCell(index) ? 8 : 0,
                        x: 0,
                        y: 0
                    )
            }
        }
        .padding(20)
        .task {
            while true {
                try? await Task.sleep(for: .seconds(0.22))
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationStep = (animationStep + 1) % 9
                }
            }
        }
    }

    private func cellColor(for index: Int) -> Color {
        if isLeadingCell(index) {
            return AppPalette.lightGreen
        }
        if isTrailingCell(index) {
            return AppPalette.green.opacity(0.7)
        }
        return AppPalette.darkGreen.opacity(0.1)
    }

    private func isLeadingCell(_ index: Int) -> Bool {
        pattern(for: stageIndex).contains(index) && index == pattern(for: stageIndex)[animationStep % pattern(for: stageIndex).count]
    }

    private func isTrailingCell(_ index: Int) -> Bool {
        let sequence = pattern(for: stageIndex)
        let trailingIndex = sequence[(animationStep + sequence.count - 1) % sequence.count]
        return index == trailingIndex
    }

    private func pattern(for stageIndex: Int) -> [Int] {
        switch stageIndex {
        case 0:
            return [0, 1, 2, 5, 8, 7, 6, 3]
        case 1:
            return [0, 4, 8, 4, 2, 4, 6, 4]
        case 2:
            return [6, 3, 0, 1, 2, 5, 8, 7]
        default:
            return [0, 1, 2, 5, 8, 7, 6, 3, 4]
        }
    }
}

private struct ProcessingBackgroundMotif: View {
    var body: some View {
        GeometryReader { geometry in
            let bayWidth: CGFloat = 72
            let roofHeight: CGFloat = 28
            let rowSpacing: CGFloat = 78
            let columns = Int(geometry.size.width / bayWidth) + 3
            let rows = Int(geometry.size.height / rowSpacing) + 3

            Path { path in
                for row in 0..<rows {
                    for column in 0..<columns {
                        let originX = CGFloat(column) * bayWidth - 24
                        let originY = CGFloat(row) * rowSpacing + 18
                        let leftX = originX
                        let centerX = originX + (bayWidth * 0.5)
                        let rightX = originX + bayWidth
                        let baseY = originY + roofHeight
                        let legBottomY = baseY + 34

                        path.move(to: CGPoint(x: leftX, y: baseY))
                        path.addLine(to: CGPoint(x: centerX, y: originY))
                        path.addLine(to: CGPoint(x: rightX, y: baseY))

                        path.move(to: CGPoint(x: leftX, y: baseY))
                        path.addLine(to: CGPoint(x: leftX, y: legBottomY))

                        path.move(to: CGPoint(x: centerX, y: baseY - 4))
                        path.addLine(to: CGPoint(x: centerX, y: legBottomY))

                        path.move(to: CGPoint(x: rightX, y: baseY))
                        path.addLine(to: CGPoint(x: rightX, y: legBottomY))
                    }
                }
            }
            .stroke(AppPalette.darkGreen.opacity(0.035), lineWidth: 1)
        }
    }
}
