import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    let onSelected: (SavedAnalysis) -> Void

    init(onSelected: @escaping (SavedAnalysis) -> Void = { _ in }) {
        self.onSelected = onSelected
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Analyses")
                        .font(AppFont.title(size: 34, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(AppPalette.darkGreen)

                    Text("Review recent tray scans and reopen any analysis instantly.")
                        .font(AppFont.body(size: 16, weight: .medium))
                        .tracking(-0.16)
                        .foregroundStyle(AppPalette.mutedText)
                }

                LazyVStack(spacing: 14) {
                    ForEach(historyStore.savedAnalyses) { saved in
                        Button {
                            onSelected(saved)
                        } label: {
                            HStack(spacing: 14) {
                                HistoryThumbnailView(imageURL: saved.cachedAnnotatedImageURL)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(saved.displayName)
                                        .font(AppFont.headline(size: 20, weight: .semibold))
                                        .tracking(-0.2)
                                        .foregroundStyle(AppPalette.darkGreen)

                                    HistoryBadge(title: "Viability", value: "\(Int(saved.result.trayStats.viabilityPct.rounded()))%")

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
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppPalette.surface.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryBadge: View {
    let title: String
    let value: String

    var body: some View {
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
