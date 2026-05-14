from __future__ import annotations

"""Batch driver for the backend pipeline with optional layout-accuracy scoring."""

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.backend.service import TrayAnalysisService, TrayAnalysisServiceConfig

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff"}
BACKEND_DEFAULTS = TrayAnalysisServiceConfig()


def build_service_config(args: argparse.Namespace, output_dir: Path) -> TrayAnalysisServiceConfig:
    """Translate CLI arguments into backend service configuration."""
    return TrayAnalysisServiceConfig(
        output_dir=output_dir,
        yolo_weights=Path(args.yolo_weights),
        tray_checkpoint=Path(args.tray_checkpoint),
        validity_checkpoint=Path(args.validity_checkpoint),
        tray_type_threshold=args.tray_type_threshold,
        rectified_width=args.rectified_width,
        save_debug=args.save_debug,
        apply_obliquity_correction=args.obliquity_correction,
    )


def build_backend_error_row(image_name: str, reason: str) -> dict[str, object]:
    """Return a consistent result row for backend failures."""
    return {
        "image": image_name,
        "pred_rows": None,
        "pred_cols": None,
        "annotated_image_path": None,
        "rectified_image_path": None,
        "result_json_path": None,
        "tray_type_key": "",
        "tray_type_confidence": None,
        "route": None,
        "method": "backend_error",
        "reason": reason,
        "crop_count": 0,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the tray pipeline on one or more images and optionally score rows/cols accuracy.",
    )
    parser.add_argument(
        "--input-dir",
        default="data/raw",
        help="Directory containing full-resolution tray images.",
    )
    parser.add_argument(
        "--output-dir",
        default="outputs/pipeline_eval",
        help="Directory for per-image outputs and evaluation files.",
    )
    parser.add_argument(
        "--yolo-weights",
        default="models/tray_segmentation/trayseg_v18_1024.pt",
        help="Path to YOLO tray segmentation weights.",
    )
    parser.add_argument(
        "--tray-checkpoint",
        default="models/tray_classifier/best_traytype_net.pth",
        help="Path to tray-type classifier checkpoint.",
    )
    parser.add_argument(
        "--validity-checkpoint",
        default="models/germination/sapling_validity_resnet18.pt",
        help="Path to the per-cell validity checkpoint used for tray viability stats.",
    )
    parser.add_argument(
        "--truth-csv",
        default=None,
        help="Optional CSV with columns: image, rows, cols.",
    )
    parser.add_argument(
        "--pattern",
        default=None,
        help="Optional glob filter inside input-dir, for example '*.jpg'.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional limit on number of images to process.",
    )
    parser.add_argument(
        "--tray-type-threshold",
        type=float,
        default=BACKEND_DEFAULTS.tray_type_threshold,
        help="Confidence threshold for trusting tray-type classifier output. Defaults to the backend service setting.",
    )
    parser.add_argument(
        "--rectified-width",
        type=int,
        default=1400,
        help="Width of perspective-corrected tray image returned by YOLO rectification.",
    )
    parser.add_argument(
        "--save-debug",
        action="store_true",
        help="Save notebook-3 fallback debug outputs.",
    )
    parser.add_argument(
        "--obliquity-correction",
        action="store_true",
        help="Enable obliquity correction before fallback CV grid inference.",
    )
    parser.add_argument(
        "--no-annotated-output",
        action="store_true",
        help="Skip saving annotated tray images with per-cell labels and tray stats.",
    )
    return parser.parse_args()


def load_truth_map(truth_csv: str | None) -> dict[str, dict[str, int]]:
    """Load optional per-image ground-truth tray dimensions from CSV."""
    if not truth_csv:
        return {}

    truth_path = Path(truth_csv)
    with truth_path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"image", "rows", "cols"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Truth CSV is missing required columns: {sorted(missing)}")

        truth_map: dict[str, dict[str, int]] = {}
        for row in reader:
            image_name = Path(row["image"]).name
            truth_map[image_name] = {
                "rows": int(row["rows"]),
                "cols": int(row["cols"]),
            }
        return truth_map


def collect_image_paths(input_dir: Path, pattern: str | None, limit: int | None) -> list[Path]:
    """Collect input images from a directory using an optional glob filter."""
    if pattern:
        paths = sorted(path for path in input_dir.glob(pattern) if path.is_file())
    else:
        paths = sorted(
            path for path in input_dir.iterdir() if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
        )
    if limit is not None:
        return paths[:limit]
    return paths


def build_result_row(
    response: dict[str, object],
    truth: dict[str, int] | None,
) -> dict[str, object]:
    """Flatten one backend response into a CSV-friendly row."""
    tray = dict(response.get("tray", {}))
    tray_stats = dict(response.get("tray_stats", {}))
    artifacts = dict(response.get("artifacts", {}))
    predicted_rows = tray.get("rows")
    predicted_cols = tray.get("cols")
    tray_type_key = tray.get("tray_type_key")
    row = {
        "image": str(response.get("source_image_name", "")),
        "pred_rows": predicted_rows,
        "pred_cols": predicted_cols,
        "annotated_image_path": artifacts.get("annotated_image_path"),
        "rectified_image_path": artifacts.get("rectified_image_path"),
        "result_json_path": artifacts.get("result_json_path"),
        "tray_type_key": "" if tray_type_key is None else "x".join(str(v) for v in tray_type_key),
        "tray_type_confidence": tray.get("tray_type_confidence"),
        "route": tray.get("route"),
        "method": tray.get("method"),
        "reason": tray.get("reason"),
        "crop_count": tray.get("crop_count"),
    }

    row.update(tray_stats)

    if truth is not None:
        row["true_rows"] = truth["rows"]
        row["true_cols"] = truth["cols"]
        row["rows_match"] = predicted_rows == truth["rows"]
        row["cols_match"] = predicted_cols == truth["cols"]
        row["exact_match"] = (predicted_rows == truth["rows"]) and (predicted_cols == truth["cols"])

    return row


def summarize_rows(rows: list[dict[str, object]], truth_map: dict[str, dict[str, int]]) -> dict[str, object]:
    """Aggregate batch-level metrics across all processed images."""
    summary: dict[str, object] = {
        "images_processed": len(rows),
        "rectification_failed": sum(1 for row in rows if row["method"] == "rectification_failed"),
        "classifier_route_count": sum(1 for row in rows if row.get("route") == "classifier"),
        "cv_fallback_route_count": sum(1 for row in rows if row.get("route") == "cv_fallback"),
    }

    viability_rows = [row for row in rows if row.get("total_cells") is not None]
    if viability_rows:
        total_cells = sum(int(row.get("total_cells", 0) or 0) for row in viability_rows)
        total_occupied = sum(int(row.get("occupied_count", 0) or 0) for row in viability_rows)
        summary["images_with_viability"] = len(viability_rows)
        summary["total_cells_scored"] = total_cells
        summary["total_occupied_cells"] = total_occupied
        summary["overall_viability_pct"] = (100.0 * total_occupied / total_cells) if total_cells else 0.0
        summary["mean_tray_viability_pct"] = (
            sum(float(row.get("viability_pct", 0.0) or 0.0) for row in viability_rows) / len(viability_rows)
        )

    if truth_map:
        evaluated = [row for row in rows if "exact_match" in row]
        exact_matches = sum(1 for row in evaluated if row["exact_match"] is True)
        rows_matches = sum(1 for row in evaluated if row["rows_match"] is True)
        cols_matches = sum(1 for row in evaluated if row["cols_match"] is True)
        total = len(evaluated)
        summary["images_with_ground_truth"] = total
        summary["exact_match_accuracy"] = (exact_matches / total) if total else None
        summary["rows_accuracy"] = (rows_matches / total) if total else None
        summary["cols_accuracy"] = (cols_matches / total) if total else None

    return summary


def write_csv(rows: list[dict[str, object]], path: Path) -> None:
    """Write heterogeneous result rows to CSV using unioned fieldnames."""
    if not rows:
        return

    fieldnames: list[str] = []
    for row in rows:
        for key in row.keys():
            if key not in fieldnames:
                fieldnames.append(key)

    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    """Run the evaluator against a directory of tray images."""
    args = parse_args()
    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if not input_dir.exists():
        raise FileNotFoundError(f"Input directory does not exist: {input_dir}")

    truth_map = load_truth_map(args.truth_csv)
    image_paths = collect_image_paths(input_dir, args.pattern, args.limit)
    if not image_paths:
        raise FileNotFoundError(f"No images found in {input_dir}")

    service = TrayAnalysisService(build_service_config(args, output_dir))
    rows: list[dict[str, object]] = []

    for image_path in image_paths:
        truth = truth_map.get(image_path.name)
        try:
            response = service.analyze_image(image_path)
        except Exception as exc:
            rows.append(build_backend_error_row(image_path.name, str(exc)))
            continue

        if args.no_annotated_output:
            annotated_path = response.get("artifacts", {}).get("annotated_image_path")
            if annotated_path:
                annotated_file = Path(str(annotated_path))
                if annotated_file.exists():
                    annotated_file.unlink()
                response["artifacts"]["annotated_image_path"] = None

        rows.append(build_result_row(response, truth))

    results_csv = output_dir / "results.csv"
    write_csv(rows, results_csv)

    summary = summarize_rows(rows, truth_map)
    summary_path = output_dir / "summary.json"
    with summary_path.open("w") as handle:
        json.dump(summary, handle, indent=2)

    print(f"Processed {len(rows)} image(s)")
    print(f"Results CSV: {results_csv}")
    print(f"Summary JSON: {summary_path}")
    if truth_map:
        print(f"Exact-match accuracy: {summary.get('exact_match_accuracy')}")
        print(f"Rows accuracy: {summary.get('rows_accuracy')}")
        print(f"Cols accuracy: {summary.get('cols_accuracy')}")


if __name__ == "__main__":
    main()
