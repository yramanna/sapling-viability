import SwiftUI
import UIKit

struct ProcessingView: View {
    @EnvironmentObject private var analysisViewModel: AnalysisViewModel
    @EnvironmentObject private var historyStore: HistoryStore

    let image: UIImage
    let onCompleted: (AnalysisResult) -> Void
    let onFailed: () -> Void

    @State private var errorMessage: String?
    @State private var attemptID = UUID()

    private let noTrayMessage = "No tray was found in this image. Please retake the photo with the full tray clearly visible."

    var body: some View {
        ZStack {
            AppPalette.surface.ignoresSafeArea()

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
            if let result = await analysisViewModel.analyze(image: image, historyStore: historyStore) {
                onCompleted(result)
            } else {
                errorMessage = analysisViewModel.errorMessage ?? "We couldn't complete the scan. Please try again."
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(AppPalette.darkGreen.opacity(0.06))
                    .frame(width: 170, height: 170)
                Circle()
                    .stroke(AppPalette.darkGreen.opacity(0.12), lineWidth: 1)
                    .frame(width: 170, height: 170)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppPalette.darkGreen)
                    .scaleEffect(4.2)
            }

            VStack(spacing: 12) {
                Text("Analysing tray data")
                    .font(AppFont.title(size: 34, weight: .bold))
                    .tracking(-0.34)
                    .foregroundStyle(AppPalette.darkGreen)

                Text("Calculating viability statistics and cell occupancy")
                    .font(AppFont.body(size: 15, weight: .medium))
                    .tracking(-0.15)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.darkGreen.opacity(0.82))
                    .padding(.horizontal, 40)
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
                Button("Try again") {
                    errorMessage = nil
                    attemptID = UUID()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Back to home") {
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
