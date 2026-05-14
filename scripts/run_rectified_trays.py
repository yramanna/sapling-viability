from __future__ import annotations

"""CLI for running separator-based grid inference on rectified tray images."""

import argparse
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from src.cell_extraction.process_warped_tray import (  # noqa: E402
    DEFAULT_OUTPUT_DIR,
    DEFAULT_RECTIFIED_DIR,
    process_warped_tray_directory,
)


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line interface for rectified-tray processing."""
    parser = argparse.ArgumentParser(
        description="Infer tray grids from rectified tray images and save outputs.",
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=DEFAULT_RECTIFIED_DIR,
        help=f"Directory containing rectified tray images. Default: {DEFAULT_RECTIFIED_DIR}",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory for debug images and cell crops. Default: {DEFAULT_OUTPUT_DIR}",
    )
    parser.add_argument("--crop-pad", type=int, default=0, help="Padding removed from each crop edge.")
    parser.add_argument("--crop-min-size", type=int, default=8, help="Minimum crop width and height.")
    parser.add_argument(
        "--no-debug",
        action="store_true",
        help="Disable debug image outputs.",
    )
    parser.add_argument(
        "--obliquity-correction",
        action="store_true",
        help="Enable residual tilt correction before grid inference.",
    )
    return parser


def main() -> None:
    """Run the rectified-tray batch processor and print a short summary."""
    parser = build_parser()
    args = parser.parse_args()

    results = process_warped_tray_directory(
        input_dir=args.input_dir,
        out_dir=args.output_dir,
        crop_pad=args.crop_pad,
        crop_min_size=args.crop_min_size,
        save_debug=not args.no_debug,
        apply_obliquity_correction=args.obliquity_correction,
    )

    print(f"Processed {len(results)} rectified tray image(s)")
    print(f"Input dir: {args.input_dir}")
    print(f"Output dir: {args.output_dir}")

    for result in results:
        print(
            f"{Path(result.image_path).name}: rows={result.rows} cols={result.cols} "
            f"crops={result.crop_count} obliquity_angle_deg={result.obliquity_angle_deg:.3f}"
        )


if __name__ == "__main__":
    main()
