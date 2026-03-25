# Greenhouse Helper iOS App

`Greenhouse Helper` is the SwiftUI iOS client for the local Bloomlogic tray-analysis workflow.

It is designed for greenhouse workers who need to:

- scan many trays in a batch
- run one-off tray checks
- inspect annotated tray results
- review saved analyses and sessions

## What the app does

The app does not run the full CV pipeline on-device. It acts as a local-network client for the backend running on a Mac in the nursery.

The app currently supports:

- batch scanning flow
- one-off tray capture or upload
- processing and error recovery
- batch result and tray result views
- tray inspection with zoom and pan
- saved analysis history
- session summary and session review

## Project location

Main project files:

- [GreenhouseHelper.xcodeproj](ios/GreenhouseHelper/GreenhouseHelper.xcodeproj)
- [App/GreenhouseHelperApp.swift](ios/GreenhouseHelper/App/GreenhouseHelperApp.swift)
- [App/AppSettings.swift](ios/GreenhouseHelper/App/AppSettings.swift)

Core screens:

- [Views/HomeView.swift](ios/GreenhouseHelper/Views/HomeView.swift)
- [Views/CaptureView.swift](ios/GreenhouseHelper/Views/CaptureView.swift)
- [Views/ProcessingView.swift](ios/GreenhouseHelper/Views/ProcessingView.swift)
- [Views/ResultsView.swift](ios/GreenhouseHelper/Views/ResultsView.swift)
- [Views/HistoryView.swift](ios/GreenhouseHelper/Views/HistoryView.swift)

Networking and persistence:

- [Services/AnalysisAPIClient.swift](ios/GreenhouseHelper/Services/AnalysisAPIClient.swift)
- [Services/HistoryStore.swift](ios/GreenhouseHelper/Services/HistoryStore.swift)
- [ViewModels/AnalysisViewModel.swift](ios/GreenhouseHelper/ViewModels/AnalysisViewModel.swift)

## App flow

### Welcome

Primary entry points:

- `Scan Trays in Batch`
- `Scan One Tray`
- `History`

### Batch workflow

1. Batch scan setup
2. Camera capture
3. Processing
4. Batch result
5. Optional tray inspection
6. Session summary / session review

### One-off workflow

1. One tray scan
2. Capture image or upload image
3. Processing
4. Tray result
5. Optional tray inspection

### Review workflow

1. Scan history
2. Session review or saved tray review
3. Tray detail

## Backend dependency

The app expects the local backend to expose:

- `GET /health`
- `POST /analyze-tray`

The backend should be reachable over local Wi-Fi, for example:

`http://192.168.1.10:8000`

Set that in:

- [App/AppSettings.swift](ios/GreenhouseHelper/App/AppSettings.swift)

Example:

```swift
static let backendBaseURL = URL(string: "http://192.168.1.10:8000")!
```

## Running the app

1. Start the backend on the nursery Mac.
2. Open [GreenhouseHelper.xcodeproj](ios/GreenhouseHelper/GreenhouseHelper.xcodeproj) in Xcode.
3. Confirm the backend IP in `AppSettings`.
4. Run on a physical iPhone on the same Wi-Fi network.

## Required assets

Important asset locations:

- [Assets.xcassets/AppIcon.appiconset](ios/GreenhouseHelper/Assets.xcassets/AppIcon.appiconset)
- [Assets.xcassets/welcome_background.imageset](ios/GreenhouseHelper/Assets.xcassets/welcome_background.imageset)
- [Assets.xcassets/bloomlogic_leaf.imageset](ios/GreenhouseHelper/Assets.xcassets/bloomlogic_leaf.imageset)

## Notes

- History is stored on-device and caches annotated result images when available.
- The app handles no-tray failures with a branded recovery state instead of blank results.
- The capture screen is a custom full-screen camera flow, not the stock image picker UI.

## Related docs

- [README.md](README.md)
- [src/backend/README.md](src/backend/README.md)
