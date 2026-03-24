import Foundation

struct AnalysisResult: Codable, Identifiable {
    let analysisId: String
    let sourceImageName: String
    let createdAt: String?
    let trayStats: TrayStats
    let tray: TrayMetadata
    let artifacts: ArtifactURLs
    let cells: [CellPrediction]

    var id: String { analysisId }

    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case sourceImageName = "source_image_name"
        case createdAt = "created_at"
        case trayStats = "tray_stats"
        case tray
        case artifacts
        case cells
    }
}

struct TrayStats: Codable {
    let viabilityPct: Double
    let occupiedCount: Int
    let emptyCount: Int
    let totalCells: Int

    enum CodingKeys: String, CodingKey {
        case viabilityPct = "viability_pct"
        case occupiedCount = "occupied_count"
        case emptyCount = "empty_count"
        case totalCells = "total_cells"
    }
}

struct TrayMetadata: Codable {
    let rows: Int?
    let cols: Int?
    let route: String?
    let method: String
    let reason: String
    let cropCount: Int
    let trayTypeConfidence: Double?
    let trayTypeKey: [Int]?

    enum CodingKeys: String, CodingKey {
        case rows
        case cols
        case route
        case method
        case reason
        case cropCount = "crop_count"
        case trayTypeConfidence = "tray_type_confidence"
        case trayTypeKey = "tray_type_key"
    }
}

struct ArtifactURLs: Codable {
    let annotatedImageURL: String?
    let rectifiedImageURL: String?
    let resultJSONURL: String?

    enum CodingKeys: String, CodingKey {
        case annotatedImageURL = "annotated_image_url"
        case rectifiedImageURL = "rectified_image_url"
        case resultJSONURL = "result_json_url"
    }
}

struct CellPrediction: Codable, Identifiable {
    let cellId: String
    let prediction: String
    let confidence: Double
    let classIndex: Int
    let cropPath: String

    var id: String { cellId }

    enum CodingKeys: String, CodingKey {
        case cellId = "cell_id"
        case prediction
        case confidence
        case classIndex = "class_index"
        case cropPath = "crop_path"
    }
}
