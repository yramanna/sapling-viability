from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
import torch

from src.cell_extraction.grid_inference import (
    crop_cells_from_grid,
    infer_grid_from_separators_with_known_layout,
)
from src.cell_extraction.process_warped_tray import (
    WarpedTrayProcessingResult,
)
from src.germination.predict import CellValidityPrediction
from src.rectification import predict_and_crop
from src.tray_layout import load_tray_type_checkpoint, predict_tray_type
from src.tray_layout.routing import RoutingDecision, choose_layout_route


@dataclass
class PipelineResult:
    image_path: str
    warped_bgr: np.ndarray | None
    tray_type_key: tuple[int, int, int, int] | None
    tray_type_confidence: float | None
    routing: RoutingDecision | None
    rows: int | None
    cols: int | None
    method: str
    reason: str
    crop_count: int
    crop_paths: list[str]
    cell_predictions: list[CellValidityPrediction] | None = None
    tray_stats: dict[str, float | int] | None = None
    annotated_image_path: str | None = None
    fallback_result: WarpedTrayProcessingResult | None = None


@dataclass(frozen=True)
class LoadedTrayTypeModel:
    model: object
    idx_to_key: list[tuple[int, int, int, int]]
    device: str | torch.device = "cpu"


def crop_cells_from_tray_type(
    warped_bgr: np.ndarray,
    grid_x: list[int],
    grid_y: list[int],
    out_dir: str | Path,
    prefix: str,
    crop_pad: int = 0,
    crop_min_size: int = 8,
) -> list[str]:
    saved = crop_cells_from_grid(
        warped_bgr,
        grid_x=grid_x,
        grid_y=grid_y,
        out_dir=out_dir,
        pad=crop_pad,
        min_size=crop_min_size,
        prefix=prefix,
    )
    return [path for _, _, path in saved]


def run_full_pipeline(
    image: np.ndarray | str | Path,
    yolo_model,
    out_dir: str | Path,
    tray_type_checkpoint_path: str | Path | None = None,
    tray_type_model: LoadedTrayTypeModel | None = None,
    prefix: str | None = None,
    tray_type_threshold: float = 0.95,
    rectified_width: int = 1400,
    rect_conf: float = 0.25,
    rect_iou: float = 0.7,
    rect_imgsz: int = 1024,
    tray_type_input_size: tuple[int, int] = (384, 640),
    tray_type_device: str = "cpu",
    crop_pad: int = 0,
    crop_min_size: int = 8,
    save_debug: bool = False,
    apply_obliquity_correction: bool = False,
) -> PipelineResult:
    image_path = str(image) if isinstance(image, (str, Path)) else ""
    if prefix is None:
        prefix = Path(image_path).stem if image_path else "tray"

    warped_bgr = predict_and_crop(
        img=image,
        model=yolo_model,
        out_w=rectified_width,
        conf=rect_conf,
        iou=rect_iou,
        imgsz=rect_imgsz,
    )
    if warped_bgr is None:
        return PipelineResult(
            image_path=image_path,
            warped_bgr=None,
            tray_type_key=None,
            tray_type_confidence=None,
            routing=None,
            rows=None,
            cols=None,
            method="rectification_failed",
            reason="no usable tray detection",
            crop_count=0,
            crop_paths=[],
            fallback_result=None,
        )

    if tray_type_model is None:
        if tray_type_checkpoint_path is None:
            raise ValueError("Either tray_type_checkpoint_path or tray_type_model must be provided.")
        model, idx_to_key, _ = load_tray_type_checkpoint(
            tray_type_checkpoint_path,
            device=tray_type_device,
        )
        tray_type_model = LoadedTrayTypeModel(
            model=model,
            idx_to_key=idx_to_key,
            device=tray_type_device,
        )

    prediction = predict_tray_type(
        model=tray_type_model.model,
        idx_to_key=tray_type_model.idx_to_key,
        rectified_bgr=warped_bgr,
        input_size=tray_type_input_size,
        device=tray_type_model.device,
    )
    routing = choose_layout_route(prediction.confidence, threshold=tray_type_threshold)

    if routing.use_classifier_layout:
        rows = int(prediction.key[1])
        cols = int(prediction.key[0])
        debug_dir = Path(out_dir) / "debug" if save_debug else None
        debug_prefix = prefix if save_debug else None
        grid_result = infer_grid_from_separators_with_known_layout(
            warped_bgr=warped_bgr,
            rows=rows,
            cols=cols,
            debug_dir=debug_dir,
            debug_prefix=debug_prefix,
        )
        crops_dir = Path(out_dir) / "cell_crops" / prefix
        crop_paths = crop_cells_from_tray_type(
            warped_bgr=warped_bgr,
            grid_x=grid_result.grid_x,
            grid_y=grid_result.grid_y,
            out_dir=crops_dir,
            prefix=prefix,
            crop_pad=crop_pad,
            crop_min_size=crop_min_size,
        )
        classifier_result = WarpedTrayProcessingResult(
            image_path=image_path,
            rows=rows,
            cols=cols,
            grid_x=grid_result.grid_x,
            grid_y=grid_result.grid_y,
            period_x=grid_result.period_x,
            period_y=grid_result.period_y,
            method=grid_result.method,
            reason=grid_result.reason,
            obliquity_angle_deg=0.0,
            crop_count=len(crop_paths),
            crop_paths=crop_paths,
        )
        if save_debug:
            debug_dir = Path(out_dir) / "debug"
            debug_dir.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(str(debug_dir / f"{prefix}_grid_overlay_final.jpg"), grid_result.overlay_bgr)
        return PipelineResult(
            image_path=image_path,
            warped_bgr=warped_bgr,
            tray_type_key=prediction.key,
            tray_type_confidence=prediction.confidence,
            routing=routing,
            rows=rows,
            cols=cols,
            method=grid_result.method,
            reason=grid_result.reason,
            crop_count=len(crop_paths),
            crop_paths=crop_paths,
            fallback_result=classifier_result,
        )

    from src.cell_extraction.process_warped_tray import process_warped_tray_image

    fallback_result = process_warped_tray_image(
        warped_bgr=warped_bgr,
        out_dir=out_dir,
        prefix=prefix,
        crop_pad=crop_pad,
        crop_min_size=crop_min_size,
        save_debug=save_debug,
        apply_obliquity_correction=apply_obliquity_correction,
    )
    return PipelineResult(
        image_path=image_path,
        warped_bgr=warped_bgr,
        tray_type_key=prediction.key,
        tray_type_confidence=prediction.confidence,
        routing=routing,
        rows=fallback_result.rows,
        cols=fallback_result.cols,
        method=fallback_result.method,
        reason=fallback_result.reason,
        crop_count=fallback_result.crop_count,
        crop_paths=fallback_result.crop_paths,
        fallback_result=fallback_result,
    )
