# Greenhouse Helper Hybrid Local Setup

## Backend

Run the local backend on the nursery Mac:

```bash
bash scripts/run_backend_mac.sh
```

Health check:

```bash
bash scripts/check_backend_mac.sh http://127.0.0.1:8000
```

## iOS app

The SwiftUI scaffold lives in:

`ios/GreenhouseHelper`

Recommended flow:

1. Open the folder in Xcode and create an iOS app project named `GreenhouseHelper`, or generate from `project.yml` if you use XcodeGen.
2. Add the `bloomlogic_leaf` asset.
3. Set the backend IP in `ios/GreenhouseHelper/App/AppSettings.swift`

Example backend URL on local Wi-Fi:

`http://192.168.1.10:8000`
