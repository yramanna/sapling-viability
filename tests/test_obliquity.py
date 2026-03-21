from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

from src.cell_extraction.obliquity import correct_obliquity, detect_obliquity_lsd


def make_tilted_line_image(angle_deg: float, size: tuple[int, int] = (420, 420)) -> np.ndarray:
    height, width = size
    image = np.zeros((height, width, 3), dtype=np.uint8)

    center = (width / 2.0, height / 2.0)
    rotation = cv2.getRotationMatrix2D(center, angle_deg, 1.0)

    for y in range(70, height - 70, 55):
        p1 = np.array([50.0, float(y), 1.0], dtype=np.float32)
        p2 = np.array([width - 50.0, float(y), 1.0], dtype=np.float32)
        x1, y1 = rotation @ p1
        x2, y2 = rotation @ p2
        cv2.line(
            image,
            (int(round(x1)), int(round(y1))),
            (int(round(x2)), int(round(y2))),
            (255, 255, 255),
            3,
        )

    return image


def test_detect_obliquity_lsd_estimates_known_tilt() -> None:
    evidence = make_tilted_line_image(angle_deg=4.0)

    angle_deg, kept = detect_obliquity_lsd(
        evidence,
        evidence,
        roi_xywh=None,
        min_hproj=45.0,
        max_abs_angle_deg=7.5,
    )

    assert kept
    assert abs(abs(angle_deg) - 4.0) < 1.0


def test_correct_obliquity_reduces_detected_tilt() -> None:
    evidence = make_tilted_line_image(angle_deg=4.5)

    before_angle, _ = detect_obliquity_lsd(evidence, evidence)
    corrected, corrected_evidence, total_angle = correct_obliquity(
        evidence,
        evidence,
        passes=2,
    )
    after_angle, _ = detect_obliquity_lsd(corrected_evidence, corrected)

    assert abs(before_angle) > 1.0
    assert abs(total_angle - before_angle) < 1.0
    assert abs(after_angle) < abs(before_angle)
    assert corrected.shape == evidence.shape
    assert corrected_evidence.shape == evidence.shape


def test_correct_obliquity_writes_debug_visualization(tmp_path: Path) -> None:
    evidence = make_tilted_line_image(angle_deg=3.5)

    correct_obliquity(
        evidence,
        evidence,
        debug_dir=tmp_path,
        debug_prefix="tiltcheck",
        passes=1,
    )

    assert (tmp_path / "tiltcheck_tilt_lines.jpg").exists()
