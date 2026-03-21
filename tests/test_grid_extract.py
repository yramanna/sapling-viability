from pathlib import Path

import cv2

from src.cell_extraction.grid_inference import (
    crop_cells_from_grid,
    infer_grid_from_separators,
)


def main() -> None:
    image_path = Path("data/processed/example.jpg")
    image = cv2.imread(str(image_path))

    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    result = infer_grid_from_separators(
        image,
        debug_dir="data/output/debug",
        debug_prefix="example",
    )

    print("rows:", result.rows)
    print("cols:", result.cols)
    print("reason:", result.reason)
    print("period_x:", result.period_x)
    print("period_y:", result.period_y)

    saved = crop_cells_from_grid(
        image,
        result.grid_x,
        result.grid_y,
        out_dir="data/output/cell_crops/example",
        prefix="example",
    )

    print(f"saved {len(saved)} crops")


if __name__ == "__main__":
    main()
