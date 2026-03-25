from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
from scipy.signal import find_peaks

from src.cell_extraction.separator_mask import (
    extract_separator_longlines,
    separator_mask_graytray_refined,
    smooth_1d,
)


@dataclass
class GridInferenceResult:
    rows: int | None
    cols: int | None
    grid_x: list[int]
    grid_y: list[int]
    period_x: float | None
    period_y: float | None
    method: str
    reason: str
    overlay_bgr: np.ndarray
    separator_mask: np.ndarray
    separator_lines: np.ndarray


def estimate_period_autocorr(sig: np.ndarray, lag_min: int, lag_max: int) -> float | None:
    """Estimate the dominant period using normalized autocorrelation."""
    sig = sig.astype(np.float32)
    if sig.size < 8:
        return None

    sig = sig - float(np.mean(sig))
    denom = float(np.dot(sig, sig)) + 1e-6
    ac = np.correlate(sig, sig, mode="full")[sig.size - 1 :] / denom

    lag_min = int(max(1, lag_min))
    lag_max = int(min(lag_max, ac.size - 1))
    if lag_max <= lag_min:
        return None

    window = ac[lag_min : lag_max + 1]
    best_idx = int(np.argmax(window))
    if window[best_idx] < 0.05:
        return None

    return float(lag_min + best_idx)


def _generate_positions(
    pitch: int | None,
    limit: int,
    proj_smooth: np.ndarray,
    peaks: np.ndarray,
    search_frac: float = 0.35,
    min_sep_frac: float = 0.60,
    nbins: int = 64,
    no_peak_placement: str = "predicted",
) -> list[int]:
    """Generate grid-line positions aligned with separator evidence."""
    if pitch is None or pitch <= 1 or limit <= 1:
        return []

    pitch_f = float(pitch)
    proj_smooth = np.asarray(proj_smooth, dtype=float)
    peaks = np.asarray(peaks, dtype=int) if peaks is not None else np.array([], dtype=int)

    if peaks.size > 0:
        phases = np.mod(peaks.astype(float), pitch_f)
        weights = proj_smooth[np.clip(peaks, 0, limit - 1)]
        bins = np.linspace(0.0, pitch_f, nbins + 1)
        hist, edges = np.histogram(phases, bins=bins, weights=weights)
        best_bin = int(np.argmax(hist))
        phase = 0.5 * (edges[best_bin] + edges[best_bin + 1])
    else:
        phase = float(int(np.argmax(proj_smooth))) % pitch_f if proj_smooth.size else 0.0

    n0 = int(np.floor((0.0 - phase) / pitch_f))
    n1 = int(np.ceil(((limit - 1) - phase) / pitch_f))

    window = int(max(2, round(search_frac * pitch_f)))
    min_sep = int(max(1, round(min_sep_frac * pitch_f)))

    output: list[int] = []
    last = -10**9

    for n in range(n0, n1 + 1):
        predicted = phase + n * pitch_f
        if predicted < -window or predicted > (limit - 1 + window):
            continue

        lo = max(0, int(round(predicted)) - window)
        hi = min(limit - 1, int(round(predicted)) + window)

        if peaks.size > 0:
            in_window = peaks[(peaks >= lo) & (peaks <= hi)]
        else:
            in_window = np.array([], dtype=int)

        if in_window.size > 0:
            best = int(in_window[np.argmax(proj_smooth[in_window])])
        else:
            if no_peak_placement == "local_argmax":
                best = int(lo + np.argmax(proj_smooth[lo : hi + 1])) if hi >= lo else int(round(predicted))
            else:
                best = max(0, min(limit - 1, int(round(predicted))))

        if best - last < min_sep:
            continue

        output.append(best)
        last = best

    return sorted(set(output))


def infer_grid_from_separators(
    warped_bgr: np.ndarray,
    debug_dir: str | Path | None = None,
    debug_prefix: str | None = None,
    min_period_px: int = 60,
    max_period_px: int | None = None,
    no_peak_placement: str = "predicted",
) -> GridInferenceResult:
    """Infer tray grid from separator evidence only."""
    height, width = warped_bgr.shape[:2]

    x0, y0 = 0, 0
    x1, y1 = width, height

    if max_period_px is None:
        max_period_px = int(max(30, min(width, height) * 0.45))

    tray_mask = separator_mask_graytray_refined(
        warped_bgr,
        debug_dir=debug_dir,
        debug_prefix=debug_prefix,
    )
    lines, horiz, vert, preclosed = extract_separator_longlines(tray_mask)

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_preclosed.jpg"), preclosed)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_longlines.jpg"), lines)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_horiz.jpg"), horiz)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_vert.jpg"), vert)

    lines_u8 = (lines > 127).astype(np.uint8) * 255
    lines_u8 = cv2.dilate(
        lines_u8,
        cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)),
        iterations=1,
    )

    lines_infer = lines_u8.copy()
    border_th = 4
    lines_infer[:border_th, :] = 255
    lines_infer[-border_th:, :] = 255
    lines_infer[:, :border_th] = 255
    lines_infer[:, -border_th:] = 255

    roi = lines_infer[y0:y1, x0:x1]
    roi_h, roi_w = roi.shape[:2]

    proj_x = (roi > 0).sum(axis=0).astype(np.float32)
    proj_y = (roi > 0).sum(axis=1).astype(np.float32)

    sx = smooth_1d(proj_x, k=max(31, roi_w // 40))
    sy = smooth_1d(proj_y, k=max(31, roi_h // 80))

    sxn = (sx - sx.min()) / (np.ptp(sx) + 1e-6)
    syn = (sy - sy.min()) / (np.ptp(sy) + 1e-6)

    dist_x = max(8, int(roi_w / 80))
    dist_y = max(8, int(roi_h / 120))

    peaks_x, _ = find_peaks(sxn, distance=dist_x, prominence=0.02)
    peaks_y, _ = find_peaks(syn, distance=dist_y, prominence=0.02)

    lag_max_x = int(min(max_period_px, roi_w // 2))
    lag_max_y = int(min(max_period_px, roi_h // 2))
    per_x = estimate_period_autocorr(
        sx,
        lag_min=min_period_px,
        lag_max=lag_max_x,
    )
    per_y = estimate_period_autocorr(
        sy,
        lag_min=min_period_px,
        lag_max=lag_max_y,
    )

    grid_x = _generate_positions(
        int(per_x) if per_x is not None else None,
        roi_w,
        sx,
        peaks_x,
        no_peak_placement=no_peak_placement,
    )
    grid_y = _generate_positions(
        int(per_y) if per_y is not None else None,
        roi_h,
        sy,
        peaks_y,
        no_peak_placement=no_peak_placement,
    )

    edge_margin_x = max(8, int(0.35 * per_x)) if per_x is not None else 12
    edge_margin_y = max(8, int(0.35 * per_y)) if per_y is not None else 12

    grid_x = sorted(set(int(v) for v in grid_x if edge_margin_x <= int(v) <= roi_w - 1 - edge_margin_x))
    grid_y = sorted(set(int(v) for v in grid_y if edge_margin_y <= int(v) <= roi_h - 1 - edge_margin_y))

    if roi_w > 1:
        grid_x = sorted(set([0] + grid_x + [roi_w - 1]))
    else:
        grid_x = [0]

    if roi_h > 1:
        grid_y = sorted(set([0] + grid_y + [roi_h - 1]))
    else:
        grid_y = [0]

    lattice_full = np.zeros((height, width), dtype=np.uint8)
    thickness = 6

    for x in grid_x:
        xx = int(round(float(x)))
        cv2.line(lattice_full, (xx, 0), (xx, height - 1), 255, thickness)

    for y in grid_y:
        yy = int(round(float(y)))
        cv2.line(lattice_full, (0, yy), (width - 1, yy), 255, thickness)

    cv2.line(lattice_full, (0, 0), (0, height - 1), 255, thickness)
    cv2.line(lattice_full, (width - 1, 0), (width - 1, height - 1), 255, thickness)
    cv2.line(lattice_full, (0, 0), (width - 1, 0), 255, thickness)
    cv2.line(lattice_full, (0, height - 1), (width - 1, height - 1), 255, thickness)

    completed_full = cv2.bitwise_or(lines_u8, lattice_full)

    overlay = warped_bgr.copy()
    for x in grid_x:
        xx = int(round(x0 + float(x)))
        cv2.line(overlay, (xx, 0), (xx, height - 1), (0, 0, 255), 2)

    for y in grid_y:
        yy = int(round(y0 + float(y)))
        cv2.line(overlay, (0, yy), (width - 1, yy), (0, 0, 255), 2)

    cols = (len(grid_x) - 1) if len(grid_x) >= 2 else None
    rows = int(round(float(roi_h) / float(per_y))) if per_y is not None and per_y > 1 else None

    reason = "ok" if (rows is not None and cols is not None) else "insufficient_periodicity"

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_longlines_raw_dilated.jpg"), lines_u8)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_lattice_raw.jpg"), lattice_full)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_completed_mask_raw.jpg"), completed_full)

        completed_overlay = warped_bgr.copy()
        completed_overlay[completed_full > 0] = (255, 255, 255)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_completed_overlay_raw.jpg"), completed_overlay)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_grid_overlay_sep.jpg"), overlay)

    return GridInferenceResult(
        rows=None if rows is None else int(rows),
        cols=None if cols is None else int(cols),
        grid_x=[int(v) for v in grid_x],
        grid_y=[int(v) for v in grid_y],
        period_x=None if per_x is None else float(per_x),
        period_y=None if per_y is None else float(per_y),
        method="separator_longlines_raw_autocorr_lattice",
        reason=reason,
        overlay_bgr=overlay,
        separator_mask=tray_mask,
        separator_lines=lines_u8,
    )


def infer_grid_from_separators_with_known_layout(
    warped_bgr: np.ndarray,
    rows: int,
    cols: int,
    debug_dir: str | Path | None = None,
    debug_prefix: str | None = None,
    no_peak_placement: str = "predicted",
) -> GridInferenceResult:
    """Place a grid using separator evidence while keeping classifier-provided rows/cols fixed."""
    height, width = warped_bgr.shape[:2]

    if rows <= 0 or cols <= 0:
        raise ValueError("rows and cols must be positive for constrained grid placement")

    tray_mask = separator_mask_graytray_refined(
        warped_bgr,
        debug_dir=debug_dir,
        debug_prefix=debug_prefix,
    )
    lines, horiz, vert, preclosed = extract_separator_longlines(tray_mask)

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_preclosed.jpg"), preclosed)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_longlines.jpg"), lines)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_horiz.jpg"), horiz)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_vert.jpg"), vert)

    lines_u8 = (lines > 127).astype(np.uint8) * 255
    lines_u8 = cv2.dilate(
        lines_u8,
        cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)),
        iterations=1,
    )

    lines_infer = lines_u8.copy()
    border_th = 4
    lines_infer[:border_th, :] = 255
    lines_infer[-border_th:, :] = 255
    lines_infer[:, :border_th] = 255
    lines_infer[:, -border_th:] = 255

    roi = lines_infer
    roi_h, roi_w = roi.shape[:2]

    proj_x = (roi > 0).sum(axis=0).astype(np.float32)
    proj_y = (roi > 0).sum(axis=1).astype(np.float32)

    sx = smooth_1d(proj_x, k=max(31, roi_w // 40))
    sy = smooth_1d(proj_y, k=max(31, roi_h // 80))

    sxn = (sx - sx.min()) / (np.ptp(sx) + 1e-6)
    syn = (sy - sy.min()) / (np.ptp(sy) + 1e-6)

    dist_x = max(8, int(roi_w / 80))
    dist_y = max(8, int(roi_h / 120))

    peaks_x, _ = find_peaks(sxn, distance=dist_x, prominence=0.02)
    peaks_y, _ = find_peaks(syn, distance=dist_y, prominence=0.02)

    expected_pitch_x = max(2, int(round(float(roi_w) / float(cols))))
    expected_pitch_y = max(2, int(round(float(roi_h) / float(rows))))

    grid_x = _generate_positions(
        expected_pitch_x,
        roi_w,
        sx,
        peaks_x,
        no_peak_placement=no_peak_placement,
    )
    grid_y = _generate_positions(
        expected_pitch_y,
        roi_h,
        sy,
        peaks_y,
        no_peak_placement=no_peak_placement,
    )

    edge_margin_x = max(8, int(0.35 * expected_pitch_x))
    edge_margin_y = max(8, int(0.35 * expected_pitch_y))

    grid_x = sorted(set(int(v) for v in grid_x if edge_margin_x <= int(v) <= roi_w - 1 - edge_margin_x))
    grid_y = sorted(set(int(v) for v in grid_y if edge_margin_y <= int(v) <= roi_h - 1 - edge_margin_y))

    if len(grid_x) > max(0, cols - 1):
        grid_x = grid_x[: cols - 1]
    if len(grid_y) > max(0, rows - 1):
        grid_y = grid_y[: rows - 1]

    while len(grid_x) < max(0, cols - 1):
        expected = int(round((len(grid_x) + 1) * roi_w / float(cols)))
        expected = max(1, min(roi_w - 2, expected))
        if expected not in grid_x:
            grid_x.append(expected)
        grid_x = sorted(set(grid_x))
        if len(grid_x) >= cols - 1:
            break

    while len(grid_y) < max(0, rows - 1):
        expected = int(round((len(grid_y) + 1) * roi_h / float(rows)))
        expected = max(1, min(roi_h - 2, expected))
        if expected not in grid_y:
            grid_y.append(expected)
        grid_y = sorted(set(grid_y))
        if len(grid_y) >= rows - 1:
            break

    grid_x = sorted(set([0] + grid_x + [roi_w - 1])) if roi_w > 1 else [0]
    grid_y = sorted(set([0] + grid_y + [roi_h - 1])) if roi_h > 1 else [0]

    lattice_full = np.zeros((height, width), dtype=np.uint8)
    thickness = 6

    for x in grid_x:
        cv2.line(lattice_full, (int(x), 0), (int(x), height - 1), 255, thickness)
    for y in grid_y:
        cv2.line(lattice_full, (0, int(y)), (width - 1, int(y)), 255, thickness)

    completed_full = cv2.bitwise_or(lines_u8, lattice_full)

    overlay = warped_bgr.copy()
    for x in grid_x:
        cv2.line(overlay, (int(x), 0), (int(x), height - 1), (0, 0, 255), 2)
    for y in grid_y:
        cv2.line(overlay, (0, int(y)), (width - 1, int(y)), (0, 0, 255), 2)

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_longlines_raw_dilated.jpg"), lines_u8)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_lattice_raw.jpg"), lattice_full)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_completed_mask_raw.jpg"), completed_full)
        completed_overlay = warped_bgr.copy()
        completed_overlay[completed_full > 0] = (255, 255, 255)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_completed_overlay_raw.jpg"), completed_overlay)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_grid_overlay_sep.jpg"), overlay)

    return GridInferenceResult(
        rows=int(rows),
        cols=int(cols),
        grid_x=[int(v) for v in grid_x],
        grid_y=[int(v) for v in grid_y],
        period_x=float(expected_pitch_x),
        period_y=float(expected_pitch_y),
        method="tray_type_classifier_separator_placement",
        reason="tray classifier confidence above threshold with separator-informed placement",
        overlay_bgr=overlay,
        separator_mask=tray_mask,
        separator_lines=lines_u8,
    )


def crop_cells_from_grid(
    img_bgr: np.ndarray,
    grid_x: list[int] | np.ndarray,
    grid_y: list[int] | np.ndarray,
    out_dir: str | Path,
    pad: int = 0,
    min_size: int = 8,
    prefix: str = "cell",
) -> list[tuple[int, int, str]]:
    """Crop each cell defined by consecutive vertical/horizontal grid lines."""
    height, width = img_bgr.shape[:2]

    xs = sorted({int(round(x)) for x in grid_x if x is not None})
    ys = sorted({int(round(y)) for y in grid_y if y is not None})

    xs = [max(0, min(width - 1, x)) for x in xs]
    ys = [max(0, min(height - 1, y)) for y in ys]

    xs = sorted(set(xs))
    ys = sorted(set(ys))

    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    saved: list[tuple[int, int, str]] = []

    for r in range(len(ys) - 1):
        y1, y2 = ys[r], ys[r + 1]
        if y2 <= y1:
            continue

        for c in range(len(xs) - 1):
            x1, x2 = xs[c], xs[c + 1]
            if x2 <= x1:
                continue

            yy1 = y1 + pad
            yy2 = y2 - pad
            xx1 = x1 + pad
            xx2 = x2 - pad

            if yy2 <= yy1 or xx2 <= xx1:
                continue
            if (yy2 - yy1) < min_size or (xx2 - xx1) < min_size:
                continue

            crop = img_bgr[yy1:yy2, xx1:xx2]
            crop_path = out_path / f"{prefix}_r{r:02d}_c{c:02d}.jpg"
            cv2.imwrite(str(crop_path), crop)
            saved.append((r, c, str(crop_path)))

    return saved
