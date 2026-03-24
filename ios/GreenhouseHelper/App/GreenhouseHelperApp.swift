import SwiftUI

@main
struct GreenhouseHelperApp: App {
    @StateObject private var analysisViewModel = AnalysisViewModel()
    @StateObject private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(analysisViewModel)
                .environmentObject(historyStore)
        }
    }
}
