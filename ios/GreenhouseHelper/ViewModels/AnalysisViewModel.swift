import Foundation
import SwiftUI
import UIKit

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var latestResult: AnalysisResult?
    @Published var errorMessage: String?

    private let apiClient = AnalysisAPIClient()

    func analyze(
        image: UIImage,
        historyStore: HistoryStore,
        sessionID: String? = nil,
        sessionName: String? = nil,
        trayNumber: Int? = nil
    ) async -> SavedAnalysis? {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let result = try await apiClient.analyze(image: image)
            latestResult = result
            return await historyStore.save(
                result: result,
                sessionID: sessionID,
                sessionName: sessionName,
                trayNumber: trayNumber
            )
        } catch {
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription,
               !description.isEmpty {
                errorMessage = description
            } else {
                errorMessage = "Analysis failed. Please try again."
            }
            return nil
        }
    }
}
