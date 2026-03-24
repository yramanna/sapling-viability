import Foundation
import UIKit

enum AnalysisAPIError: LocalizedError {
    case invalidImageData
    case server(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Unable to prepare the selected image for upload."
        case .server(let message):
            return message
        case .emptyResult:
            return "No tray was found in this image. Please retake the photo with the full tray clearly visible."
        }
    }
}

final class AnalysisAPIClient {
    private struct APIErrorResponse: Decodable {
        let detail: String
    }

    func analyze(image: UIImage) async throws -> AnalysisResult {
        let endpoint = AppSettings.backendBaseURL.appendingPathComponent("analyze-tray")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AnalysisAPIError.invalidImageData
        }

        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fieldName: "image",
            fileName: "tray.jpg",
            mimeType: "image/jpeg",
            data: imageData
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= http.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AnalysisAPIError.server(apiError.detail)
            }
            throw AnalysisAPIError.server("Analysis failed. Please try again.")
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(AnalysisResult.self, from: data)

        guard result.trayStats.totalCells > 0, !result.cells.isEmpty else {
            throw AnalysisAPIError.emptyResult
        }

        return result
    }

    private func makeMultipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(lineBreak)"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(data)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
