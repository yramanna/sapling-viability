from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

import cv2
import numpy as np

from src.cell_extraction.grid_inference import (
    GridInferenceResult,
    crop_cells_from_grid,
    infer_grid_from_separators,
)
from src.cell_extraction.obliquity import correct_obliquity
from src.cell_extraction.separator_mask import separator_mask_graytray_refined


@dataclass
class WarpedTrayProcessingResult:
    image_path: str
    rows: int | None
    cols: int | None
    grid_x: list[int]
    grid_y: list[int]
    period_x: float | None
    period_y: float | None
    method: str
    reason: str
    obliquity_angle_deg: float
    crop_count: int
    crop_paths: list[str]


DEFAULT_RECTIFIED_DIR = Path("data/processed")
DEFAULT_OUTPUT_DIR = Path("data/output")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"}


def process_warped_tray_image(
    warped_bgr: np.ndarray,
    out_dir: str | Path,
    prefix: str = "tray",
    crop_pad: int = 0,
    crop_min_size: int = 8,
    save_debug: bool = True,
    apply_obliquity_correction: bool = False,
    obliquity_roi_xywh: tuple[int, int, int, int] | None = None,
    obliquity_min_hproj: float = 45.0,
    obliquity_max_abs_angle_deg: float = 7.5,
    obliquity_max_tilt_deg: float = 10.0,
    obliquity_passes: int = 2,
) -> WarpedTrayProcessingResult:
    """
    Process a rectified tray image into inferred grid + per-cell crops.

    Parameters
    ----------
    warped_bgr:
        Rectified top-down tray image.
    out_dir:
        Root output directory for debug images and cell crops.
    prefix:
        Prefix for saved files.
    crop_pad:
        Optional padding removed from each side of a crop.
    crop_min_size:
        Minimum allowed crop width/height.
    save_debug:
        Whether to save debug outputs.
    apply_obliquity_correction:
        Whether to correct residual tilt before grid inference.

    Returns
    -------
    WarpedTrayProcessingResult
    """
    out_dir = Path(out_dir)
    debug_dir = out_dir / "debug"
    crops_dir = out_dir / "cell_crops" / prefix

    debug_arg = debug_dir if save_debug else None
    debug_prefix = prefix if save_debug else None

    corrected_warp = warped_bgr
    obliquity_angle_deg = 0.0

    if apply_obliquity_correction:
        separator_mask = separator_mask_graytray_refined(
            warped_bgr,
            debug_dir=debug_arg,
            debug_prefix=debug_prefix,
        )
        evidence_bgr = cv2.cvtColor(separator_mask, cv2.COLOR_GRAY2BGR)
        corrected_warp, _, obliquity_angle_deg = correct_obliquity(
            evidence_bgr=evidence_bgr,
            warped_bgr=warped_bgr,
            roi_xywh=obliquity_roi_xywh,
            min_hproj=obliquity_min_hproj,
            horiz_max_abs_angle_deg=obliquity_max_abs_angle_deg,
            max_tilt_deg=obliquity_max_tilt_deg,
            debug_dir=debug_arg,
            debug_prefix=debug_prefix,
            passes=obliquity_passes,
        )

    grid_result: GridInferenceResult = infer_grid_from_separators(
        corrected_warp,
        debug_dir=debug_arg,
        debug_prefix=debug_prefix,
    )

    saved = crop_cells_from_grid(
        corrected_warp,
        grid_result.grid_x,
        grid_result.grid_y,
        out_dir=crops_dir,
        pad=crop_pad,
        min_size=crop_min_size,
        prefix=prefix,
    )

    crop_paths = [path for _, _, path in saved]

    if save_debug:
        debug_dir.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_dir / f"{prefix}_grid_overlay_final.jpg"), grid_result.overlay_bgr)
        if apply_obliquity_correction:
            cv2.imwrite(str(debug_dir / f"{prefix}_warped_obliquity_corrected.jpg"), corrected_warp)

    return WarpedTrayProcessingResult(
        image_path="",
        rows=grid_result.rows,
        cols=grid_result.cols,
        grid_x=grid_result.grid_x,
        grid_y=grid_result.grid_y,
        period_x=grid_result.period_x,
        period_y=grid_result.period_y,
        method=grid_result.method,
        reason=grid_result.reason,
        obliquity_angle_deg=float(obliquity_angle_deg),
        crop_count=len(saved),
        crop_paths=crop_paths,
    )


def process_warped_tray_path(
    image_path: str | Path,
    out_dir: str | Path = DEFAULT_OUTPUT_DIR,
    prefix: str | None = None,
    crop_pad: int = 0,
    crop_min_size: int = 8,
    save_debug: bool = True,
    apply_obliquity_correction: bool = False,
    obliquity_roi_xywh: tuple[int, int, int, int] | None = None,
    obliquity_min_hproj: float = 45.0,
    obliquity_max_abs_angle_deg: float = 7.5,
    obliquity_max_tilt_deg: float = 10.0,
    obliquity_passes: int = 2,
) -> WarpedTrayProcessingResult:
    """
    Load a rectified tray image from disk and process it.
    """
    image_path = Path(image_path)
    warped_bgr = cv2.imread(str(image_path))

    if warped_bgr is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    if prefix is None:
        prefix = image_path.stem

    result = process_warped_tray_image(
        warped_bgr=warped_bgr,
        out_dir=out_dir,
        prefix=prefix,
        crop_pad=crop_pad,
        crop_min_size=crop_min_size,
        save_debug=save_debug,
        apply_obliquity_correction=apply_obliquity_correction,
        obliquity_roi_xywh=obliquity_roi_xywh,
        obliquity_min_hproj=obliquity_min_hproj,
        obliquity_max_abs_angle_deg=obliquity_max_abs_angle_deg,
        obliquity_max_tilt_deg=obliquity_max_tilt_deg,
        obliquity_passes=obliquity_passes,
    )
    result.image_path = str(image_path)
    return result


def process_warped_tray_directory(
    input_dir: str | Path = DEFAULT_RECTIFIED_DIR,
    out_dir: str | Path = DEFAULT_OUTPUT_DIR,
    crop_pad: int = 0,
    crop_min_size: int = 8,
    save_debug: bool = True,
    apply_obliquity_correction: bool = False,
    obliquity_roi_xywh: tuple[int, int, int, int] | None = None,
    obliquity_min_hproj: float = 45.0,
    obliquity_max_abs_angle_deg: float = 7.5,
    obliquity_max_tilt_deg: float = 10.0,
    obliquity_passes: int = 2,
) -> list[WarpedTrayProcessingResult]:
    """
    Process all rectified tray images in a directory.
    """
    input_path = Path(input_dir)
    if not input_path.exists():
        raise FileNotFoundError(f"Input directory does not exist: {input_path}")
    if not input_path.is_dir():
        raise NotADirectoryError(f"Input path is not a directory: {input_path}")

    image_paths = sorted(
        path for path in input_path.iterdir() if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )

    results: list[WarpedTrayProcessingResult] = []
    for image_path in image_paths:
        results.append(
            process_warped_tray_path(
                image_path=image_path,
                out_dir=out_dir,
                prefix=image_path.stem,
                crop_pad=crop_pad,
                crop_min_size=crop_min_size,
                save_debug=save_debug,
                apply_obliquity_correction=apply_obliquity_correction,
                obliquity_roi_xywh=obliquity_roi_xywh,
                obliquity_min_hproj=obliquity_min_hproj,
                obliquity_max_abs_angle_deg=obliquity_max_abs_angle_deg,
                obliquity_max_tilt_deg=obliquity_max_tilt_deg,
                obliquity_passes=obliquity_passes,
            )
        )

    return results


def result_to_dict(result: WarpedTrayProcessingResult) -> dict:
    return asdict(result)
