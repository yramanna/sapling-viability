from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np


def detect_obliquity_lsd(
    evidence_bgr: np.ndarray,
    warped_bgr: np.ndarray,
    roi_xywh: tuple[int, int, int, int] | None = None,
    min_hproj: float = 45.0,
    max_abs_angle_deg: float = 7.5,
) -> tuple[float, list[tuple[float, float, float, float]]]:
    """Estimate residual tray tilt from near-horizontal line segments."""
    height, width = warped_bgr.shape[:2]

    if roi_xywh is None:
        x = int(0.10 * width)
        y = int(0.10 * height)
        w = int(0.80 * width)
        h = int(0.50 * height)
    else:
        x, y, w, h = roi_xywh
        x = int(max(0, x))
        y = int(max(0, y))
        w = int(max(1, w))
        h = int(max(1, h))

    x2 = int(min(width, x + w))
    y2 = int(min(height, y + h))
    if x2 - x < 10 or y2 - y < 10:
        return 0.0, []

    roi = evidence_bgr[y:y2, x:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)

    lsd = cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
    detected = lsd.detect(gray)[0]
    if detected is None or len(detected) == 0:
        return 0.0, []

    angles: list[float] = []
    weights: list[float] = []
    kept: list[tuple[float, float, float, float]] = []

    for line in detected:
        x1, y1, xB, yB = line[0]
        dx = xB - x1
        dy = yB - y1

        if abs(dx) < float(min_hproj):
            continue

        angle_deg = float(np.degrees(np.arctan2(dy, dx)))
        if angle_deg > 90.0:
            angle_deg -= 180.0
        elif angle_deg < -90.0:
            angle_deg += 180.0

        if abs(angle_deg) > float(max_abs_angle_deg):
            continue

        length = float(np.hypot(dx, dy))
        angles.append(angle_deg)
        weights.append(length)
        kept.append((x1 + x, y1 + y, xB + x, yB + y))

    if len(angles) < 3:
        return 0.0, kept

    angles_array = np.asarray(angles, dtype=np.float32)
    weights_array = np.asarray(weights, dtype=np.float32)

    order = np.argsort(angles_array)
    angles_sorted = angles_array[order]
    weights_sorted = weights_array[order]

    if len(angles_sorted) > 4:
        angles_sorted = angles_sorted[1:-1]
        weights_sorted = weights_sorted[1:-1]

    estimate = float(np.sum(angles_sorted * weights_sorted) / (np.sum(weights_sorted) + 1e-6))
    return estimate, kept


def correct_obliquity(
    evidence_bgr: np.ndarray,
    warped_bgr: np.ndarray,
    roi_xywh: tuple[int, int, int, int] | None = None,
    min_hproj: float = 45.0,
    horiz_max_abs_angle_deg: float = 7.5,
    max_tilt_deg: float = 10.0,
    debug_dir: str | Path | None = None,
    debug_prefix: str | None = None,
    passes: int = 2,
) -> tuple[np.ndarray, np.ndarray, float]:
    """Rotate a rectified tray image to remove residual tilt."""
    corrected = warped_bgr.copy()
    evidence = evidence_bgr.copy()
    total_angle = 0.0
    kept_lines_last: list[tuple[float, float, float, float]] = []

    for _ in range(int(passes)):
        angle_deg, kept_lines = detect_obliquity_lsd(
            evidence,
            corrected,
            roi_xywh=roi_xywh,
            min_hproj=min_hproj,
            max_abs_angle_deg=horiz_max_abs_angle_deg,
        )
        kept_lines_last = kept_lines

        if abs(angle_deg) > float(max_tilt_deg):
            angle_deg = 0.0

        if abs(angle_deg) < 1e-3:
            break

        height, width = corrected.shape[:2]
        center = (width / 2.0, height / 2.0)
        matrix = cv2.getRotationMatrix2D(center, -angle_deg, 1.0)

        corrected = cv2.warpAffine(
            corrected,
            matrix,
            (width, height),
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_REPLICATE,
        )
        evidence = cv2.warpAffine(
            evidence,
            matrix,
            (width, height),
            flags=cv2.INTER_NEAREST,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0),
        )
        total_angle += angle_deg

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        vis = warped_bgr.copy()
        for x1, y1, x2, y2 in kept_lines_last:
            cv2.line(vis, (int(x1), int(y1)), (int(x2), int(y2)), (0, 0, 255), 2)
        cv2.putText(
            vis,
            f"tilt={total_angle:.3f} deg (passes={passes})",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.0,
            (0, 0, 255),
            2,
            cv2.LINE_AA,
        )
        cv2.imwrite(str(debug_path / f"{debug_prefix}_tilt_lines.jpg"), vis)

    return corrected, evidence, total_angle
