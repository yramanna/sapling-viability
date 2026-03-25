import Foundation
import SwiftUI

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var savedAnalyses: [SavedAnalysis] = []
    @Published private(set) var savedSessions: [SavedSession] = []

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("analysis_history.json")
    }()
    private let imagesDirectoryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("analysis_images", isDirectory: true)
    }()

    init() {
        load()
    }

    func save(
        result: AnalysisResult,
        sessionID: String? = nil,
        sessionName: String? = nil,
        trayNumber: Int? = nil
    ) async -> SavedAnalysis {
        let cachedImageFileName = await cacheAnnotatedImage(for: result)
        let saved = SavedAnalysis(
            id: result.analysisId,
            savedAt: Date(),
            result: result,
            cachedAnnotatedImageFileName: cachedImageFileName,
            sessionID: sessionID,
            sessionName: sessionName,
            trayNumber: trayNumber
        )
        savedAnalyses.insert(saved, at: 0)
        persist()
        return saved
    }

    func setFlagged(_ flagged: Bool, for analysisID: String) {
        guard let index = savedAnalyses.firstIndex(where: { $0.id == analysisID }) else { return }
        savedAnalyses[index].isFlagged = flagged
        persist()
    }

    func deleteAnalysis(id analysisID: String) {
        guard let index = savedAnalyses.firstIndex(where: { $0.id == analysisID }) else { return }
        let removed = savedAnalyses.remove(at: index)
        if let fileName = removed.cachedAnnotatedImageFileName {
            let imageURL = imagesDirectoryURL.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: imageURL)
        }
        persist()
    }

    func analyses(in sessionID: String) -> [SavedAnalysis] {
        savedSessions.first(where: { $0.id == sessionID })?.analyses ?? []
    }

    func clearAll() {
        savedAnalyses = []
        try? FileManager.default.removeItem(at: saveURL)
        try? FileManager.default.removeItem(at: imagesDirectoryURL)
        rebuildSessions()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SavedAnalysis].self, from: data) {
            savedAnalyses = decoded
            rebuildSessions()
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(savedAnalyses) {
            try? data.write(to: saveURL, options: .atomic)
        }
        rebuildSessions()
    }

    private func rebuildSessions() {
        let grouped = Dictionary(grouping: savedAnalyses) { saved -> String in
            saved.sessionID ?? "single-\(saved.id)"
        }

        savedSessions = grouped.compactMap { key, analyses in
            let sorted = analyses.sorted { lhs, rhs in lhs.savedAt > rhs.savedAt }
            guard let newest = sorted.first,
                  let oldest = sorted.last else { return nil }
            let name = newest.sessionID == nil
                ? newest.displayName
                : newest.sessionDisplayName
            return SavedSession(
                id: key,
                name: name,
                startedAt: oldest.savedAt,
                analyses: sorted
            )
        }
        .sorted { lhs, rhs in lhs.startedAt > rhs.startedAt }
    }

    private func cacheAnnotatedImage(for result: AnalysisResult) async -> String? {
        guard let annotatedImageURLString = result.artifacts.annotatedImageURL,
              let annotatedImageURL = URL(string: annotatedImageURLString) else {
            return nil
        }

        try? FileManager.default.createDirectory(
            at: imagesDirectoryURL,
            withIntermediateDirectories: true
        )

        let fileName = "\(result.analysisId).jpg"
        let destinationURL = imagesDirectoryURL.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return fileName
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: annotatedImageURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            try data.write(to: destinationURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }
}
