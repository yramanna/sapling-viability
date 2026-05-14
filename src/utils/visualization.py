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
    style: str = "premium",
) -> np.ndarray:
    """Draw a tray validity overlay."""
    if warped_bgr is None:
        raise ValueError("warped_bgr is required to render an overlay.")
    if rows <= 0 or cols <= 0:
        raise ValueError("rows and cols must be positive to render an overlay.")

    if style == "legacy":
        return _render_validity_overlay_legacy(
            warped_bgr=warped_bgr,
            predictions=predictions,
            rows=rows,
            cols=cols,
            grid_x=grid_x,
            grid_y=grid_y,
        )
    if style != "premium":
        raise ValueError(f"Unsupported overlay style: {style}")

    return _render_validity_overlay_premium(
        warped_bgr=warped_bgr,
        predictions=predictions,
        rows=rows,
        cols=cols,
        grid_x=grid_x,
        grid_y=grid_y,
    )


def _render_validity_overlay_legacy(
    warped_bgr: np.ndarray,
    predictions: Sequence[CellValidityPrediction],
    rows: int,
    cols: int,
    grid_x: Sequence[int] | None = None,
    grid_y: Sequence[int] | None = None,
) -> np.ndarray:
    """Preserve the previous annotation style for easy rollback."""
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


def _rounded_mask(shape: tuple[int, int], radius: int) -> np.ndarray:
    height, width = shape
    mask = np.zeros((height, width), dtype=np.uint8)
    cv2.rectangle(mask, (radius, 0), (width - radius - 1, height - 1), 255, -1)
    cv2.rectangle(mask, (0, radius), (width - 1, height - radius - 1), 255, -1)
    cv2.circle(mask, (radius, radius), radius, 255, -1)
    cv2.circle(mask, (width - radius - 1, radius), radius, 255, -1)
    cv2.circle(mask, (radius, height - radius - 1), radius, 255, -1)
    cv2.circle(mask, (width - radius - 1, height - radius - 1), radius, 255, -1)
    return mask


def _render_validity_overlay_premium(
    warped_bgr: np.ndarray,
    predictions: Sequence[CellValidityPrediction],
    rows: int,
    cols: int,
    grid_x: Sequence[int] | None = None,
    grid_y: Sequence[int] | None = None,
) -> np.ndarray:
    tray_image = warped_bgr.copy()
    height, width = tray_image.shape[:2]
    xs = _normalize_grid_lines(grid_x, width, cols)
    ys = _normalize_grid_lines(grid_y, height, rows)

    min_cell_w = max(1, min(xs[i + 1] - xs[i] for i in range(min(len(xs) - 1, cols))))
    min_cell_h = max(1, min(ys[i + 1] - ys[i] for i in range(min(len(ys) - 1, rows))))
    cell_inset_x = max(4, int(round(min_cell_w * 0.10)))
    cell_inset_y = max(4, int(round(min_cell_h * 0.10)))
    outline_thickness = max(2, int(round(min(width, height) / 650)))
    font = cv2.FONT_HERSHEY_DUPLEX
    base_font_scale = max(0.30, min(width, height) / 2100.0)
    text_thickness = max(1, int(round(base_font_scale * 2)))
    badge_pad_x = max(4, int(round(width / 420)))
    badge_pad_y = max(3, int(round(height / 520)))

    occupied_fill = np.array((72, 190, 64), dtype=np.float32)   # bright green, BGR
    occupied_outline = tuple(int(v) for v in (92, 228, 84))
    empty_fill = np.array((76, 76, 212), dtype=np.float32)      # premium red, BGR
    empty_outline = tuple(int(v) for v in (92, 92, 236))
    occupied_fill_alpha = 0.14
    empty_fill_alpha = 0.10

    image = tray_image.astype(np.float32)
    outline_overlay = tray_image.copy()

    for prediction in predictions:
        row, col = _prediction_row_col(prediction, cols=cols)
        if row >= len(ys) - 1 or col >= len(xs) - 1:
            continue

        x1 = xs[col] + cell_inset_x
        x2 = xs[col + 1] - cell_inset_x
        y1 = ys[row] + cell_inset_y
        y2 = ys[row + 1] - cell_inset_y
        if x2 <= x1 or y2 <= y1:
            continue

        is_occupied = prediction.prediction == "occupied"
        fill_color = occupied_fill if is_occupied else empty_fill
        outline_color = occupied_outline if is_occupied else empty_outline

        fill_alpha = occupied_fill_alpha if is_occupied else empty_fill_alpha
        image[y1:y2, x1:x2] = (
            (1.0 - fill_alpha) * image[y1:y2, x1:x2]
            + fill_alpha * fill_color
        )

        cv2.rectangle(
            outline_overlay,
            (x1, y1),
            (x2, y2),
            outline_color,
            outline_thickness,
            cv2.LINE_AA,
        )

        label = f"{'O' if is_occupied else 'E'} {prediction.confidence * 100:.0f}%"
        font_scale = base_font_scale
        cell_w = max(1, x2 - x1)
        cell_h = max(1, y2 - y1)
        (text_w, text_h), baseline = cv2.getTextSize(label, font, font_scale, text_thickness)
        while font_scale > 0.18:
            badge_w = text_w + badge_pad_x * 2
            badge_h = text_h + baseline + badge_pad_y * 2
            if badge_w <= cell_w and badge_h <= cell_h:
                break
            font_scale -= 0.04
            (text_w, text_h), baseline = cv2.getTextSize(label, font, font_scale, text_thickness)

        badge_w = min(cell_w, text_w + badge_pad_x * 2)
        badge_h = min(cell_h, text_h + baseline + badge_pad_y * 2)
        badge_x2 = min(x2, x1 + badge_w)
        badge_y2 = min(y2, y1 + badge_h)
        cv2.rectangle(
            outline_overlay,
            (x1, y1),
            (badge_x2, badge_y2),
            outline_color,
            -1,
            cv2.LINE_AA,
        )
        text_x = x1 + badge_pad_x
        text_y = min(badge_y2 - baseline - badge_pad_y, y1 + text_h + badge_pad_y)
        text_y = max(text_y, y1 + text_h)
        cv2.putText(
            outline_overlay,
            label,
            (text_x, text_y),
            font,
            font_scale,
            (255, 255, 255),
            text_thickness,
            cv2.LINE_AA,
        )

    composed = cv2.addWeighted(outline_overlay, 0.90, image.astype(np.uint8), 0.10, 0)

    shadow_pad = max(8, int(round(min(width, height) / 48)))
    canvas_h = height + shadow_pad * 2
    canvas_w = width + shadow_pad * 2
    canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    tray_x = shadow_pad
    tray_y = shadow_pad

    shadow = np.zeros((canvas_h, canvas_w), dtype=np.uint8)
    radius = max(14, int(round(min(width, height) / 22)))
    shadow_radius = max(14, int(round(radius * 1.1)))
    shadow_mask = _rounded_mask((height, width), radius)
    shadow[
        tray_y + 5 : tray_y + 5 + height,
        tray_x + 6 : tray_x + 6 + width,
    ] = shadow_mask
    shadow = cv2.GaussianBlur(shadow, (0, 0), sigmaX=shadow_radius, sigmaY=shadow_radius)
    shadow_alpha = (shadow.astype(np.float32) / 255.0) * 0.14
    shadow_rgb = np.zeros((canvas_h, canvas_w, 3), dtype=np.float32)
    for channel in range(3):
        canvas[:, :, channel] = (
            shadow_rgb[:, :, channel] * shadow_alpha
        ).astype(np.uint8)
    canvas[:, :, 3] = np.clip(shadow_alpha * 255.0, 0, 255).astype(np.uint8)

    canvas_region = canvas[tray_y : tray_y + height, tray_x : tray_x + width]
    canvas_region[:, :, :3] = composed
    canvas_region[:, :, 3] = 255
    canvas[tray_y : tray_y + height, tray_x : tray_x + width] = canvas_region

    tray_mask = _rounded_mask((height, width), radius)
    tray_region = canvas[tray_y : tray_y + height, tray_x : tray_x + width]
    tray_region[tray_mask == 0] = 0
    canvas[tray_y : tray_y + height, tray_x : tray_x + width] = tray_region

    return canvas
