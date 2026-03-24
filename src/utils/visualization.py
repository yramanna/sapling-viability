from __future__ import annotations

import re
from pathlib import Path
from typing import Sequence

import cv2
import numpy as np

from src.germination.predict import CellValidityPrediction

_RC_PATTERN = re.compile(r"_r(?P<row>\d+)_c(?P<col>\d+)$")
_IDX_PATTERN = re.compile(r"_cell_(?P<idx>\d+)$")


def _uniform_grid_lines(length: int, bins: int) -> list[int]:
    if bins <= 0:
        return [0, max(0, length - 1)]
    return [int(round(v)) for v in np.linspace(0, max(0, length - 1), bins + 1)]


def _normalize_grid_lines(lines: Sequence[int] | None, length: int, bins: int) -> list[int]:
    if lines:
        norm = sorted({max(0, min(length - 1, int(round(v)))) for v in lines})
        if len(norm) >= 2:
            return norm
    return _uniform_grid_lines(length, bins)


def _prediction_row_col(
    prediction: CellValidityPrediction,
    cols: int,
) -> tuple[int, int]:
    stem = Path(prediction.crop_path).stem
    rc_match = _RC_PATTERN.search(stem)
    if rc_match:
        return int(rc_match.group("row")), int(rc_match.group("col"))

    idx_match = _IDX_PATTERN.search(stem)
    if idx_match:
        idx = int(idx_match.group("idx"))
        return idx // cols, idx % cols

    raise ValueError(f"Could not infer cell position from crop name: {prediction.crop_path}")


def render_validity_overlay(
    warped_bgr: np.ndarray,
    predictions: Sequence[CellValidityPrediction],
    tray_stats: dict[str, float | int] | None,
    rows: int,
    cols: int,
    grid_x: Sequence[int] | None = None,
    grid_y: Sequence[int] | None = None,
) -> np.ndarray:
    """Draw per-cell validity labels on the tray image."""
    if warped_bgr is None:
        raise ValueError("warped_bgr is required to render an overlay.")
    if rows <= 0 or cols <= 0:
        raise ValueError("rows and cols must be positive to render an overlay.")

    tray_image = warped_bgr.copy()
    height, width = tray_image.shape[:2]
    xs = _normalize_grid_lines(grid_x, width, cols)
    ys = _normalize_grid_lines(grid_y, height, rows)

    font = cv2.FONT_HERSHEY_DUPLEX
    base_font_scale = max(0.35, min(width, height) / 1800.0)
    text_thickness = max(1, int(round(base_font_scale * 2)))
    box_thickness = max(1, int(round(min(width, height) / 500)))
    badge_pad_x = max(4, int(round(width / 400)))
    badge_pad_y = max(3, int(round(height / 500)))
    cell_inset_x = max(2, int(round(width / (cols * 18))))
    cell_inset_y = max(2, int(round(height / (rows * 18))))
    border_alpha = 0.8

    image = tray_image.copy()

    for prediction in predictions:
        row, col = _prediction_row_col(prediction, cols=cols)
        if row >= len(ys) - 1 or col >= len(xs) - 1:
            continue

        cell_x1 = xs[col] + cell_inset_x
        cell_x2 = xs[col + 1] - cell_inset_x
        cell_y1 = ys[row] + cell_inset_y
        cell_y2 = ys[row + 1] - cell_inset_y
        x1, x2, y1, y2 = cell_x1, cell_x2, cell_y1, cell_y2
        if x2 <= x1 or y2 <= y1:
            continue
        color = (0, 180, 0) if prediction.prediction == "occupied" else (0, 0, 180)
        label = f"{prediction.prediction[:1].upper()} {prediction.confidence * 100:.0f}%"
        cell_w = x2 - x1
        cell_h = y2 - y1
        font_scale = base_font_scale
        (text_w, text_h), baseline = cv2.getTextSize(label, font, font_scale, text_thickness)
        max_badge_w = max(1, cell_w)
        max_badge_h = max(1, cell_h)

        while font_scale > 0.2:
            badge_w = text_w + badge_pad_x * 2
            badge_h = text_h + baseline + badge_pad_y * 2
            if badge_w <= max_badge_w and badge_h <= max_badge_h:
                break
            font_scale -= 0.05
            (text_w, text_h), baseline = cv2.getTextSize(label, font, font_scale, text_thickness)

        badge_w = min(max_badge_w, text_w + badge_pad_x * 2)
        badge_h = min(max_badge_h, text_h + baseline + badge_pad_y * 2)

        border_overlay = image.copy()
        cv2.rectangle(border_overlay, (x1, y1), (x2, y2), color, box_thickness)
        cv2.addWeighted(border_overlay, border_alpha, image, 1.0 - border_alpha, 0, image)
        badge_x2 = min(cell_x2, x1 + badge_w)
        badge_y2 = min(cell_y2, y1 + badge_h)
        cv2.rectangle(image, (x1, y1), (badge_x2, badge_y2), color, -1)
        text_x = x1 + badge_pad_x
        text_y = min(badge_y2 - baseline - badge_pad_y, y1 + text_h + badge_pad_y)
        text_y = max(text_y, y1 + text_h)
        cv2.putText(
            image,
            label,
            (text_x, text_y),
            font,
            font_scale,
            (255, 255, 255),
            text_thickness,
            cv2.LINE_AA,
        )

    return image
