from src.cell_extraction.process_warped_tray import process_warped_tray_path


def main() -> None:
    result = process_warped_tray_path(
        image_path="data/processed/example.jpg",
        out_dir="data/output",
        prefix="example",
        crop_pad=0,
        crop_min_size=8,
        save_debug=True,
    )

    print("image_path:", result.image_path)
    print("rows:", result.rows)
    print("cols:", result.cols)
    print("method:", result.method)
    print("reason:", result.reason)
    print("crop_count:", result.crop_count)


if __name__ == "__main__":
    main()
