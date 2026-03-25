import Foundation

struct SavedAnalysis: Codable, Identifiable {
    let id: String
    let savedAt: Date
    let result: AnalysisResult
    let cachedAnnotatedImageFileName: String?
    let sessionID: String?
    let sessionName: String?
    let trayNumber: Int?
    var isFlagged: Bool

    init(
        id: String,
        savedAt: Date,
        result: AnalysisResult,
        cachedAnnotatedImageFileName: String?,
        sessionID: String? = nil,
        sessionName: String? = nil,
        trayNumber: Int? = nil,
        isFlagged: Bool = false
    ) {
        self.id = id
        self.savedAt = savedAt
        self.result = result
        self.cachedAnnotatedImageFileName = cachedAnnotatedImageFileName
        self.sessionID = sessionID
        self.sessionName = sessionName
        self.trayNumber = trayNumber
        self.isFlagged = isFlagged
    }

    enum CodingKeys: String, CodingKey {
        case id
        case savedAt
        case result
        case cachedAnnotatedImageFileName
        case sessionID
        case sessionName
        case trayNumber
        case isFlagged
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        result = try container.decode(AnalysisResult.self, forKey: .result)
        cachedAnnotatedImageFileName = try container.decodeIfPresent(String.self, forKey: .cachedAnnotatedImageFileName)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        sessionName = try container.decodeIfPresent(String.self, forKey: .sessionName)
        trayNumber = try container.decodeIfPresent(Int.self, forKey: .trayNumber)
        isFlagged = try container.decodeIfPresent(Bool.self, forKey: .isFlagged) ?? false
    }

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

    var trayLabel: String {
        if let trayNumber {
            return "Tray \(trayNumber)"
        }
        return savedAt.formatted(date: .omitted, time: .shortened)
    }

    var sessionDisplayName: String {
        if let sessionName, !sessionName.isEmpty {
            return sessionName
        }
        return savedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct SavedSession: Identifiable {
    let id: String
    let name: String
    let startedAt: Date
    let analyses: [SavedAnalysis]

    var trayCount: Int { analyses.count }
    var flaggedCount: Int { analyses.filter(\.isFlagged).count }

    var averageViability: Double {
        guard !analyses.isEmpty else { return 0 }
        let total = analyses.reduce(0.0) { $0 + $1.result.trayStats.viabilityPct }
        return total / Double(analyses.count)
    }
}
