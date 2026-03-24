import Foundation
import SwiftUI

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var savedAnalyses: [SavedAnalysis] = []

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

    func save(result: AnalysisResult) async {
        let cachedImageFileName = await cacheAnnotatedImage(for: result)
        let saved = SavedAnalysis(
            id: result.analysisId,
            savedAt: Date(),
            result: result,
            cachedAnnotatedImageFileName: cachedImageFileName
        )
        savedAnalyses.insert(saved, at: 0)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SavedAnalysis].self, from: data) {
            savedAnalyses = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(savedAnalyses) {
            try? data.write(to: saveURL, options: .atomic)
        }
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
