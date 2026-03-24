from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

import cv2
from ultralytics import YOLO

from src.germination import load_validity_model, predict_validity_for_tray, summarize_tray_validity
from src.pipeline.run_full_pipeline import run_full_pipeline
from src.utils.visualization import render_validity_overlay


@dataclass(frozen=True)
class TrayAnalysisServiceConfig:
    output_dir: Path = Path("outputs/mobile_backend")
    yolo_weights: Path = Path("models/tray_segmentation/trayseg_v18_1024.pt")
    tray_checkpoint: Path = Path("models/tray_classifier/best_traytype_net.pth")
    validity_checkpoint: Path = Path("models/germination/sapling_validity_resnet18.pt")
    tray_type_threshold: float = 0.90
    rectified_width: int = 1400
    save_debug: bool = False
    apply_obliquity_correction: bool = False


class TrayAnalysisService:
    NO_TRAY_MESSAGE = "No tray was found in this image. Please retake the photo with the full tray clearly visible."
    MIN_VALID_TOTAL_CELLS = 6

    def __init__(self, config: TrayAnalysisServiceConfig):
        self.config = config
        self.output_dir = config.output_dir
        self.upload_dir = self.output_dir / "uploads"
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        self.yolo_model = YOLO(str(config.yolo_weights))
        self.validity_model, self.validity_device = load_validity_model(config.validity_checkpoint)

    def analyze_image(self, image_path: str | Path) -> dict:
        image_path = Path(image_path)
        self._validate_source_image(image_path)
        analysis_id = f"{image_path.stem}_{uuid4().hex[:8]}"
        created_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        analysis_dir = self.output_dir / "analyses" / analysis_id
        analysis_dir.mkdir(parents=True, exist_ok=True)

        result = run_full_pipeline(
            image=image_path,
            yolo_model=self.yolo_model,
            tray_type_checkpoint_path=self.config.tray_checkpoint,
            out_dir=analysis_dir,
            prefix=image_path.stem,
            tray_type_threshold=self.config.tray_type_threshold,
            rectified_width=self.config.rectified_width,
            save_debug=self.config.save_debug,
            apply_obliquity_correction=self.config.apply_obliquity_correction,
        )

        if result.crop_paths:
            cell_predictions = predict_validity_for_tray(
                crop_paths=result.crop_paths,
                model=self.validity_model,
                device=self.validity_device,
            )
        else:
            cell_predictions = []

        tray_stats = summarize_tray_validity(cell_predictions)
        result.cell_predictions = cell_predictions
        result.tray_stats = tray_stats

        if not cell_predictions or tray_stats.get("total_cells", 0) < self.MIN_VALID_TOTAL_CELLS:
            raise ValueError(self.NO_TRAY_MESSAGE)

        rectified_path = None
        if result.warped_bgr is not None:
            rectified_dir = analysis_dir / "warped"
            rectified_dir.mkdir(parents=True, exist_ok=True)
            rectified_path = rectified_dir / f"{image_path.stem}.rectified.jpg"
            cv2.imwrite(str(rectified_path), result.warped_bgr)

        annotated_path = self._save_annotated_result(analysis_dir=analysis_dir, result=result)
        result.annotated_image_path = None if annotated_path is None else str(annotated_path)

        payload = asdict(result)
        payload["warped_bgr"] = None
        result_json_path = analysis_dir / f"{image_path.stem}.result.json"
        with result_json_path.open("w") as handle:
            json.dump(payload, handle, indent=2)

        return {
            "analysis_id": analysis_id,
            "source_image_name": image_path.name,
            "created_at": created_at,
            "tray_stats": tray_stats,
            "tray": {
                "rows": result.rows,
                "cols": result.cols,
                "route": None if result.routing is None else (
                    "classifier" if result.routing.use_classifier_layout else "cv_fallback"
                ),
                "method": result.method,
                "reason": result.reason,
                "crop_count": result.crop_count,
                "tray_type_confidence": result.tray_type_confidence,
                "tray_type_key": None if result.tray_type_key is None else list(result.tray_type_key),
            },
            "artifacts": {
                "annotated_image_path": None if annotated_path is None else str(annotated_path),
                "rectified_image_path": None if rectified_path is None else str(rectified_path),
                "result_json_path": str(result_json_path),
            },
            "cells": [asdict(prediction) for prediction in cell_predictions],
        }

    def _save_annotated_result(self, analysis_dir: Path, result) -> Path | None:
        if result.warped_bgr is None or result.rows is None or result.cols is None:
            return None

        annotated_dir = analysis_dir / "annotated"
        annotated_dir.mkdir(parents=True, exist_ok=True)

        grid_x = None
        grid_y = None
        if result.fallback_result is not None:
            grid_x = result.fallback_result.grid_x
            grid_y = result.fallback_result.grid_y

        annotated_bgr = render_validity_overlay(
            warped_bgr=result.warped_bgr,
            predictions=result.cell_predictions or [],
            tray_stats=result.tray_stats,
            rows=int(result.rows),
            cols=int(result.cols),
            grid_x=grid_x,
            grid_y=grid_y,
        )
        annotated_path = annotated_dir / f"{Path(result.image_path).stem}.annotated.jpg"
        cv2.imwrite(str(annotated_path), annotated_bgr)
        return annotated_path

    def _validate_source_image(self, image_path: Path) -> None:
        image = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if image is None or image.size == 0:
            raise ValueError(self.NO_TRAY_MESSAGE)

        mean_intensity = float(image.mean())
        std_intensity = float(image.std())

        # Reject obviously unusable captures before the tray pipeline runs.
        if mean_intensity < 12.0 or mean_intensity > 245.0 or std_intensity < 8.0:
            raise ValueError(self.NO_TRAY_MESSAGE)
