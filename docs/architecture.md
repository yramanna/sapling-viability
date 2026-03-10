# Architecture

## End-to-end flow

Input tray image
→ YOLO tray segmentation
→ tray crop + top-down rectification
→ tray classifier
→ routing step:
   - if confidence >= 0.90: use predicted tray layout
   - else: use CV fallback to infer cells
→ cell crops
→ germination classifier
→ health classifier on germinated cells
→ tray-level aggregation

## Core modules

### 1. Tray segmentation
Purpose:
- isolate the tray from the input image

### 2. Rectification
Purpose:
- normalize tray geometry into a top-down view

### 3. Tray layout inference
Purpose:
- predict tray type or tray dimensions
- decide whether to use learned layout or CV fallback

### 4. Cell extraction
Purpose:
- generate per-cell crops from the rectified tray image

### 5. Cell classification
Purpose:
- classify germination
- classify health among germinated cells

### 6. Analytics
Purpose:
- convert cell predictions into tray-level metrics

## Design principle

Keep each stage replaceable.
A future version should be able to swap:
- a different segmentation model
- a different tray classifier
- a different CV grid extractor
- different binary classifiers
without rewriting the whole pipeline.
