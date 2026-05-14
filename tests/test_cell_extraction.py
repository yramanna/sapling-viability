from __future__ import annotations

"""Focused tests for the rectified-tray CV extraction pipeline."""

from dataclasses import asdict
import inspect
from pathlib import Path

import cv2
import numpy as np

from src.cell_extraction.grid_inference import (
    _generate_positions,
    crop_cells_from_grid,
    infer_grid_from_separators_with_known_layout,
)
from src.cell_extraction.process_warped_tray import (
    DEFAULT_OUTPUT_DIR,
    DEFAULT_RECTIFIED_DIR,
    process_warped_tray_directory,
    process_warped_tray_image,
    process_warped_tray_path,
)


def make_synthetic_grid_image(
    rows: int = 4,
    cols: int = 6,
    cell_h: int = 40,
    cell_w: int = 50,
    line_thickness: int = 4,
) -> np.ndarray:
    """Create a simple synthetic tray image with visible row and column separators."""
    height = rows * cell_h + (rows + 1) * line_thickness
    width = cols * cell_w + (cols + 1) * line_thickness

    img = np.full((height, width, 3), 180, dtype=np.uint8)

    # draw horizontal grid lines
    y = 0
    for _ in range(rows + 1):
        cv2.rectangle(img, (0, y), (width - 1, y + line_thickness - 1), (110, 110, 110), -1)
        y += cell_h + line_thickness

    # draw vertical grid lines
    x = 0
    for _ in range(cols + 1):
        cv2.rectangle(img, (x, 0), (x + line_thickness - 1, height - 1), (110, 110, 110), -1)
        x += cell_w + line_thickness

    # add simple green-ish content inside cells so the image is less degenerate
    for r in range(rows):
        for c in range(cols):
            x1 = line_thickness + c * (cell_w + line_thickness)
            y1 = line_thickness + r * (cell_h + line_thickness)
            x2 = x1 + cell_w - 1
            y2 = y1 + cell_h - 1
            cv2.circle(
                img,
                ((x1 + x2) // 2, (y1 + y2) // 2),
                radius=max(4, min(cell_w, cell_h) // 6),
                color=(60, 140, 60),
                thickness=-1,
            )

    return img


def test_crop_cells_from_grid_saves_expected_number(tmp_path: Path) -> None:
    img = np.full((120, 180, 3), 255, dtype=np.uint8)

    # 3 rows x 4 cols => 12 crops
    grid_x = [0, 45, 90, 135, 179]
    grid_y = [0, 40, 80, 119]

    saved = crop_cells_from_grid(
        img_bgr=img,
        grid_x=grid_x,
        grid_y=grid_y,
        out_dir=tmp_path / "crops",
        pad=0,
        min_size=8,
        prefix="unit",
    )

    assert len(saved) == 12

    for r, c, crop_path in saved:
        assert 0 <= r < 3
        assert 0 <= c < 4
        assert Path(crop_path).exists(), f"missing crop file: {crop_path}"


def test_crop_cells_from_grid_respects_min_size(tmp_path: Path) -> None:
    img = np.full((30, 30, 3), 255, dtype=np.uint8)

    # Each cell is too small once min_size is enforced
    grid_x = [0, 5, 10, 15]
    grid_y = [0, 5, 10, 15]

    saved = crop_cells_from_grid(
        img_bgr=img,
        grid_x=grid_x,
        grid_y=grid_y,
        out_dir=tmp_path / "tiny",
        min_size=12,
        prefix="tiny",
    )

    assert len(saved) == 0


def test_process_warped_tray_image_runs_on_synthetic_grid(tmp_path: Path) -> None:
    img = make_synthetic_grid_image(rows=4, cols=6)

    result = process_warped_tray_image(
        warped_bgr=img,
        out_dir=tmp_path,
        prefix="synthetic",
        crop_pad=0,
        crop_min_size=8,
        save_debug=True,
    )

    # Smoke-test expectations: pipeline runs and returns a structured result
    assert result.method != ""
    assert result.reason != ""
    assert isinstance(result.grid_x, list)
    assert isinstance(result.grid_y, list)
    assert isinstance(result.obliquity_angle_deg, float)
    assert result.crop_count >= 1

    # Verify crop files exist
    assert len(result.crop_paths) == result.crop_count
    for crop_path in result.crop_paths:
        assert Path(crop_path).exists(), f"missing crop file: {crop_path}"

    # Verify debug overlay exists when save_debug=True
    debug_overlay = tmp_path / "debug" / "synthetic_grid_overlay_final.jpg"
    assert debug_overlay.exists(), f"missing debug overlay: {debug_overlay}"
    corrected_warp = tmp_path / "debug" / "synthetic_warped_obliquity_corrected.jpg"
    assert not corrected_warp.exists()


def test_result_to_dict_is_serializable(tmp_path: Path) -> None:
    """Warped-tray results should remain dataclass-serializable for artifact writing."""
    img = make_synthetic_grid_image(rows=3, cols=3)

    result = process_warped_tray_image(
        warped_bgr=img,
        out_dir=tmp_path,
        prefix="dictcheck",
        save_debug=False,
    )

    payload = asdict(result)

    assert isinstance(payload, dict)
    assert "rows" in payload
    assert "cols" in payload
    assert "crop_count" in payload
    assert "crop_paths" in payload
    assert "obliquity_angle_deg" in payload
    assert payload["crop_count"] == len(payload["crop_paths"])


def test_process_warped_tray_image_can_disable_obliquity_correction(tmp_path: Path) -> None:
    img = make_synthetic_grid_image(rows=3, cols=4)

    result = process_warped_tray_image(
        warped_bgr=img,
        out_dir=tmp_path,
        prefix="noobliq",
        save_debug=True,
        apply_obliquity_correction=False,
    )

    assert result.obliquity_angle_deg == 0.0
    assert not (tmp_path / "debug" / "noobliq_warped_obliquity_corrected.jpg").exists()


def test_process_warped_tray_path_defaults_output_dir_to_data_output() -> None:
    signature = inspect.signature(process_warped_tray_path)
    assert signature.parameters["out_dir"].default == DEFAULT_OUTPUT_DIR


def test_process_warped_tray_directory_processes_rectified_images(tmp_path: Path) -> None:
    input_dir = tmp_path / "processed"
    output_dir = tmp_path / "output"
    input_dir.mkdir()

    for stem in ("tray_a", "tray_b"):
        cv2.imwrite(str(input_dir / f"{stem}.jpg"), make_synthetic_grid_image(rows=2, cols=2))

    results = process_warped_tray_directory(
        input_dir=input_dir,
        out_dir=output_dir,
        save_debug=False,
    )

    assert len(results) == 2
    assert [Path(result.image_path).stem for result in results] == ["tray_a", "tray_b"]
    assert all(result.crop_count >= 1 for result in results)
    assert all(Path(result.crop_paths[0]).is_relative_to(output_dir) for result in results)


def test_default_directory_constants_match_requested_layout() -> None:
    assert DEFAULT_RECTIFIED_DIR == Path("data/processed")
    assert DEFAULT_OUTPUT_DIR == Path("data/output")


def test_generate_positions_uses_predicted_position_when_no_peak_exists() -> None:
    positions = _generate_positions(
        pitch=100,
        limit=500,
        proj_smooth=np.zeros(500, dtype=np.float32),
        peaks=np.array([10, 110, 210]),
        search_frac=0.2,
        min_sep_frac=0.6,
        nbins=32,
        no_peak_placement="predicted",
    )

    assert positions[:3] == [10, 110, 210]
    assert positions[3] > 280
    assert positions[4] > 380


def test_infer_grid_from_separators_with_known_layout_keeps_counts() -> None:
    img = make_synthetic_grid_image(rows=4, cols=6)

    result = infer_grid_from_separators_with_known_layout(
        warped_bgr=img,
        rows=4,
        cols=6,
    )

    assert result.rows == 4
    assert result.cols == 6
    assert len(result.grid_x) == 7
    assert len(result.grid_y) == 5
