# Bloomlogic Tray Viability

Bloomlogic is a computer-vision pipeline and local hybrid mobile app for greenhouse tray analysis. It takes a tray image, rectifies the tray, extracts cropped cells, classifies each cell as `occupied` or `empty`, and returns tray-level viability statistics plus an annotated tray image.

The repository now supports two connected surfaces:

- a Python backend for tray analysis and artifact generation
- a SwiftUI iOS app, `Greenhouse Helper`, for capture, upload, review, and batch scanning

## Current scope

The current production path uses the validity model as the tray viability signal:

- `occupied` = viable
- `empty` = non-viable

The health classifier notebooks are still in the repo, but the app/backend flow is currently centered on validity only.

## End-to-end flow

1. Detect the tray with YOLO.
2. Rectify the tray to a top-down view.
3. Predict tray layout with the tray classifier.
4. Fall back to separator-based CV grid extraction when classifier confidence is low.
5. Crop each cell.
6. Classify each crop with the validity model.
7. Aggregate tray-level metrics:
   - viability percent
   - occupied count
   - empty count
   - total cells
8. Render an annotated tray image with per-cell labels.

## Repository layout

- `src/backend/` - FastAPI service for local tray analysis
- `src/pipeline/` - end-to-end tray processing orchestration
- `src/tray_segmentation/` - tray segmentation inference
- `src/rectification/` - tray crop and perspective warp
- `src/tray_layout/` - tray classifier and routing logic
- `src/cell_extraction/` - fallback CV grid extraction and cropping
- `src/germination/` - validity model inference helpers
- `src/utils/` - rendering and supporting utilities
- `scripts/` - training, evaluation, and local backend runners
- `ios/GreenhouseHelper/` - SwiftUI app source and assets
- `notebooks/` - research and experimentation notebooks

## Main components

### Python pipeline

The Python side is responsible for:

- tray detection and rectification
- grid inference and crop extraction
- validity classification
- tray statistics
- annotated output images

Key entrypoints:

- [scripts/evaluate_pipeline.py](scripts/evaluate_pipeline.py)
- [src/pipeline/run_full_pipeline.py](src/pipeline/run_full_pipeline.py)

### Local backend

The backend wraps the pipeline in a local FastAPI service intended to run on a nursery Mac on the same Wi-Fi as the iPhone.

Key files:

- [src/backend/api.py](src/backend/api.py)
- [src/backend/service.py](src/backend/service.py)
- [scripts/run_backend.py](scripts/run_backend.py)

Detailed backend instructions live in [src/backend/README.md](src/backend/README.md).

### iOS app

`Greenhouse Helper` is a SwiftUI client for:

- batch tray scanning
- one-off tray scans
- session review
- saved analysis history
- detailed tray inspection

Detailed iOS app instructions live in [ios/GreenhouseHelper/README.md](ios/GreenhouseHelper/README.md).

## Quick start

### 1. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 2. Run the local backend

```bash
python3 scripts/run_backend.py --host 0.0.0.0 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

### 3. Point the iOS app at the local backend

Update the backend base URL in:

- [ios/GreenhouseHelper/App/AppSettings.swift](ios/GreenhouseHelper/App/AppSettings.swift)

Example:

```swift
static let backendBaseURL = URL(string: "http://192.168.1.10:8000")!
```

### 4. Run the app in Xcode

Open:

- [ios/GreenhouseHelper/GreenhouseHelper.xcodeproj](ios/GreenhouseHelper/GreenhouseHelper.xcodeproj)

Then run on a physical iPhone connected to the same Wi-Fi as the backend machine.

## API summary

The local backend currently exposes:

- `GET /health`
- `POST /analyze-tray`

`POST /analyze-tray` accepts a multipart image upload and returns:

- `analysis_id`
- `created_at`
- `tray_stats`
- tray metadata
- artifact URLs
- per-cell predictions

## Output artifacts

The backend writes analysis outputs under:

- `outputs/mobile_backend/`

Typical artifacts include:

- uploaded source image
- rectified tray image
- annotated tray image
- result JSON

## Current app flow

The iOS app supports:

- `Scan Trays in Batch`
  - batch setup
  - capture
  - processing
  - batch result
  - session summary / session review
- `Scan One Tray`
  - capture or upload
  - processing
  - tray result
- `Scan History`

## Notes

- The backend is designed for local network use, not public internet deployment.
- The no-tray failure path is normalized to a user-friendly message instead of blank results.
- The backend rejects obviously invalid captures and analyses with fewer than 6 total cells.

## Related docs

- [src/backend/README.md](src/backend/README.md)
- [ios/GreenhouseHelper/README.md](ios/GreenhouseHelper/README.md)
