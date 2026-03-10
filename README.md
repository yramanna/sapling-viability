# Plant Tray Viability

Computer vision pipeline for greenhouse tray analysis.

## Overview

This project processes overhead images of plant trays and outputs tray-level germination and health metrics.

Pipeline:
1. Segment the tray using YOLO
2. Rectify the tray to a top-down view
3. Predict tray type / dimensions using a tray classifier
4. If classifier confidence is below 0.90, fall back to classical CV cell extraction
5. Classify each cell for germination
6. Classify germinated cells for health
7. Aggregate predictions into tray-level metrics

## Repository layout

- `src/tray_segmentation/` — tray mask inference
- `src/rectification/` — crop and top-down warp
- `src/tray_layout/` — tray classifier and routing logic
- `src/cell_extraction/` — CV fallback and cell cropping
- `src/germination/` — binary germination classifier
- `src/health/` — binary health classifier
- `src/analytics/` — tray-level metrics and reporting
- `src/pipeline/` — end-to-end orchestration

## Quick start

Install dependencies:

```bash
pip install -r requirements.txt
