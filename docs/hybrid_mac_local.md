# Hybrid Mac Local Setup

This document describes the current local deployment setup for Bloomlogic:

- a Mac runs the tray-analysis backend on the local network
- an iPhone runs the `Greenhouse Helper` app
- both devices are on the same Wi-Fi

## 1. Start the backend on the Mac

Install Python dependencies if needed:

```bash
pip install -r requirements.txt
```

Run the backend:

```bash
python3 scripts/run_backend.py --host 0.0.0.0 --port 8000
```

Optional helper script:

```bash
bash scripts/run_backend_mac.sh
```

Health check:

```bash
bash scripts/check_backend_mac.sh http://127.0.0.1:8000
```

You can also test directly:

```bash
curl http://127.0.0.1:8000/health
```

## 2. Find the Mac's local IP

Typical commands:

```bash
ipconfig getifaddr en0
```

If needed:

```bash
ipconfig getifaddr en1
```

Example result:

`192.168.1.10`

## 3. Point the iPhone app at the backend

Set the backend URL in:

- [ios/GreenhouseHelper/App/AppSettings.swift](ios/GreenhouseHelper/App/AppSettings.swift)

Example:

```swift
static let backendBaseURL = URL(string: "http://192.168.1.10:8000")!
```

## 4. Run the iOS app in Xcode

Open:

- [ios/GreenhouseHelper/GreenhouseHelper.xcodeproj](ios/GreenhouseHelper/GreenhouseHelper.xcodeproj)

Then:

1. choose your Apple development team
2. confirm signing is valid
3. connect a physical iPhone
4. run the app on that device

## 5. Confirm local-network behavior

Make sure:

- the Mac and iPhone are on the same Wi-Fi
- the backend is still running
- the app is using the correct local IP

The current app supports:

- `Scan Trays in Batch`
- `Scan One Tray`
- `Scan History`

## 6. Backend outputs

The backend writes results under:

- `outputs/mobile_backend/`

Typical generated artifacts:

- uploaded source image
- rectified tray image
- annotated tray image
- result JSON

## Notes

- This is a local hybrid setup, not a public hosted deployment.
- The backend returns a no-tray error for unusable captures and analyses with fewer than 6 cells.
- The app caches saved analysis history on-device.

## Related docs

- [README.md](README.md)
- [ios/GreenhouseHelper/README.md](ios/GreenhouseHelper/README.md)
- [src/backend/README.md](src/backend/README.md)
