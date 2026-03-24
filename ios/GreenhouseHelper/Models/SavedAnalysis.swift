import Foundation

struct SavedAnalysis: Codable, Identifiable {
    let id: String
    let savedAt: Date
    let result: AnalysisResult
    let cachedAnnotatedImageFileName: String?

    var cachedAnnotatedImageURL: URL? {
        guard let cachedAnnotatedImageFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs
            .appendingPathComponent("analysis_images", isDirectory: true)
            .appendingPathComponent(cachedAnnotatedImageFileName)
    }

    var displayName: String {
        savedAt.formatted(date: .abbreviated, time: .shortened)
    }
}
