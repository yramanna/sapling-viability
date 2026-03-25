import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var showingClearConfirmation = false

    let onSessionSelected: (SavedSession) -> Void
    let onSingleSelected: (SavedAnalysis) -> Void

    init(
        onSessionSelected: @escaping (SavedSession) -> Void = { _ in },
        onSingleSelected: @escaping (SavedAnalysis) -> Void = { _ in }
    ) {
        self.onSessionSelected = onSessionSelected
        self.onSingleSelected = onSingleSelected
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scan History")
                            .font(AppFont.title(size: 34, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(AppPalette.darkGreen)

                        Text("Review saved batch sessions and reopen any tray when you need a closer look.")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .tracking(-0.16)
                            .foregroundStyle(AppPalette.mutedText)
                    }

                    LazyVStack(spacing: 14) {
                        ForEach(historyStore.savedSessions) { session in
                            if session.analyses.count > 1 || session.analyses.first?.sessionID != nil {
                                Button {
                                    onSessionSelected(session)
                                } label: {
                                    sessionCard(session)
                                }
                                .buttonStyle(.plain)
                            } else if let single = session.analyses.first {
                                Button {
                                    onSingleSelected(single)
                                } label: {
                                    singleCard(single)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppPalette.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear History") {
                        showingClearConfirmation = true
                    }
                    .font(AppFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(historyStore.savedAnalyses.isEmpty ? AppPalette.mutedText : .red)
                    .disabled(historyStore.savedAnalyses.isEmpty)
                }
            }

            if showingClearConfirmation {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        showingClearConfirmation = false
                    }

                VStack(spacing: 18) {
                    Text("Clear all saved analyses?")
                        .font(AppFont.title(size: 28, weight: .bold))
                        .tracking(-0.28)
                        .foregroundStyle(AppPalette.darkGreen)
                        .multilineTextAlignment(.center)

                    Text("This will remove all saved sessions, trays, and cached annotated images from the device.")
                        .font(AppFont.body(size: 15, weight: .medium))
                        .tracking(-0.15)
                        .foregroundStyle(AppPalette.mutedText)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        Button("Clear History") {
                            historyStore.clearAll()
                            showingClearConfirmation = false
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Cancel") {
                            showingClearConfirmation = false
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppPalette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppPalette.cardBorder.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: AppPalette.black.opacity(0.12), radius: 22, x: 0, y: 10)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.top, 140)
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    private func sessionCard(_ session: SavedSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.name)
                        .font(AppFont.headline(size: 22, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(AppPalette.darkGreen)

                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppFont.body(size: 14, weight: .medium))
                        .tracking(-0.14)
                        .foregroundStyle(AppPalette.mutedText)
                }

                Spacer()

                Text("\(session.trayCount) trays")
                    .font(AppFont.caption(size: 12, weight: .semibold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.lightGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppPalette.darkGreen)
                    )
            }

            HStack(spacing: 12) {
                metricChip(title: "Avg viability", value: "\(Int(session.averageViability.rounded()))%")
                metricChip(title: "Flagged", value: "\(session.flaggedCount)")
            }

            Text("Open session")
                .font(AppFont.body(size: 14, weight: .semibold))
                .tracking(-0.14)
                .foregroundStyle(AppPalette.darkGreen.opacity(0.76))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.cardBorder.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppPalette.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func singleCard(_ saved: SavedAnalysis) -> some View {
        HStack(spacing: 14) {
            HistoryThumbnailView(imageURL: saved.cachedAnnotatedImageURL)

            VStack(alignment: .leading, spacing: 8) {
                Text(saved.displayName)
                    .font(AppFont.headline(size: 20, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(AppPalette.darkGreen)

                metricChip(title: "Viability", value: "\(Int(saved.result.trayStats.viabilityPct.rounded()))%")

                Text("\(saved.result.trayStats.occupiedCount) occupied / \(saved.result.trayStats.totalCells) total cells")
                    .font(AppFont.body(size: 14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(AppPalette.mutedText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.cardBorder.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppPalette.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func metricChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(AppFont.caption(size: 11, weight: .semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.mutedText.opacity(0.8))
            Text(value)
                .font(AppFont.body(size: 13, weight: .semibold))
                .tracking(-0.13)
                .foregroundStyle(AppPalette.darkGreen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(AppPalette.darkGreen.opacity(0.07))
        )
    }
}

struct SessionDetailView: View {
    let session: SavedSession
    let onTraySelected: (SavedAnalysis) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.name)
                        .font(AppFont.title(size: 30, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(AppPalette.darkGreen)

                    Text("\(session.trayCount) trays scanned")
                        .font(AppFont.body(size: 15, weight: .medium))
                        .foregroundStyle(AppPalette.mutedText)
                }

                LazyVStack(spacing: 12) {
                    ForEach(session.analyses) { saved in
                        Button {
                            onTraySelected(saved)
                        } label: {
                            HStack(spacing: 12) {
                                HistoryThumbnailView(imageURL: saved.cachedAnnotatedImageURL)
                                    .frame(width: 84, height: 84)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(saved.trayLabel)
                                            .font(AppFont.body(size: 17, weight: .semibold))
                                            .foregroundStyle(AppPalette.darkGreen)
                                        if saved.isFlagged {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(AppPalette.lightGreen)
                                        }
                                    }

                                    Text("\(Int(saved.result.trayStats.viabilityPct.rounded()))% viable")
                                        .font(AppFont.body(size: 15, weight: .semibold))
                                        .foregroundStyle(AppPalette.darkGreen)

                                    Text("\(saved.result.trayStats.occupiedCount) occupied / \(saved.result.trayStats.totalCells) total")
                                        .font(AppFont.body(size: 14, weight: .medium))
                                        .foregroundStyle(AppPalette.mutedText)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(AppPalette.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppPalette.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppPalette.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryThumbnailView: View {
    let imageURL: URL?

    var body: some View {
        Group {
            if let imageURL,
               let image = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppPalette.darkGreen.opacity(0.12))
                    Image(systemName: "photo")
                        .foregroundStyle(AppPalette.green)
                }
            }
        }
        .frame(width: 98, height: 98)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
