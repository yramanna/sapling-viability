# Bloomlogic Local Backend

This backend wraps the tray-analysis pipeline in a local FastAPI service intended to run on a Mac in the nursery.

The main use case is:

- the Mac runs the backend on local Wi-Fi
- the iPhone app uploads tray images to that Mac
- the backend returns tray statistics, per-cell predictions, and artifact URLs

## Main files

- [api.py](src/backend/api.py)
- [service.py](src/backend/service.py)
- [scripts/run_backend.py](scripts/run_backend.py)

## What the backend does

For each uploaded tray image it:

1. validates the source image
2. runs the full tray pipeline
3. extracts or infers the tray grid
4. classifies each cell as `occupied` or `empty`
5. aggregates tray-level viability stats
6. renders an annotated tray image
7. stores result artifacts under `outputs/mobile_backend/`

## Current validation rules

The backend currently rejects:

- obviously unusable source images
  - near-black
  - near-white
  - extremely low-contrast
- tray analyses with fewer than 6 total cells

All of those cases return the same user-friendly message:

`No tray was found in this image. Please retake the photo with the full tray clearly visible.`

## Run locally

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the backend:

```bash
python3 scripts/run_backend.py --host 0.0.0.0 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## API

### `GET /health`

Returns:

```json
{"status":"ok"}
```

### `POST /analyze-tray`

Accepts:

- multipart form upload
- field name: `image`

Returns:

- `analysis_id`
- `source_image_name`
- `created_at`
- `tray_stats`
- tray metadata
- artifact URLs
- `cells`

## Artifact output

Artifacts are written under:

- `outputs/mobile_backend/`

Typical structure:

- `uploads/`
- `analyses/<analysis_id>/warped/`
- `analyses/<analysis_id>/annotated/`
- `analyses/<analysis_id>/<result>.json`

## iOS app integration

The SwiftUI app uses this backend over local Wi-Fi.

Configure the app base URL in:

- [ios/GreenhouseHelper/App/AppSettings.swift](ios/GreenhouseHelper/App/AppSettings.swift)

Example:

```swift
static let backendBaseURL = URL(string: "http://192.168.1.10:8000")!
```

## Notes

- This backend is for local-network use, not hardened public deployment.
- Models are loaded once when the service starts.
- Annotated outputs currently include per-cell overlays only, not a tray-stats banner.

## Related docs

- [README.md](README.md)
- [ios/GreenhouseHelper/README.md](ios/GreenhouseHelper/README.md)
