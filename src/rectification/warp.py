from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

from src.rectification.corners import robust_corners_from_polygon


def _warp_from_box(
    img_bgr: np.ndarray,
    box: np.ndarray,
    out_w: int = 512,
) -> np.ndarray | None:
    if box is None or len(box) != 4:
        return None

    top_left, top_right, bottom_right, bottom_left = box.astype(np.float32)
    width_top = np.linalg.norm(top_right - top_left)
    width_bottom = np.linalg.norm(bottom_right - bottom_left)
    height_right = np.linalg.norm(bottom_right - top_right)
    height_left = np.linalg.norm(bottom_left - top_left)

    src_w = max(width_top, width_bottom)
    src_h = max(height_left, height_right)
    if src_w <= 1 or src_h <= 1:
        return None

    out_h = max(1, int(round(out_w * (src_h / src_w))))
    dst = np.array(
        [
            [0, 0],
            [out_w - 1, 0],
            [out_w - 1, out_h - 1],
            [0, out_h - 1],
        ],
        dtype=np.float32,
    )
    matrix = cv2.getPerspectiveTransform(box.astype(np.float32), dst)
    return cv2.warpPerspective(img_bgr, matrix, (out_w, out_h))


def predict_and_crop(
    img: np.ndarray | str | Path,
    model,
    out_w: int = 512,
    conf: float = 0.25,
    iou: float = 0.7,
    imgsz: int = 1024,
) -> np.ndarray | None:
    """
    Run a YOLO segmentation model and return a perspective-corrected tray crop.

    The crop is computed on the resized inference image and returns `None` when
    no usable mask polygon is found.
    """
    if isinstance(img, (str, Path)):
        img = cv2.imread(str(img))
    if img is None:
        return None

    img_resized = cv2.resize(img, (imgsz, imgsz), interpolation=cv2.INTER_LINEAR)
    results = model.predict(
        source=img_resized,
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        verbose=False,
    )
    result = results[0]

    polygon = None
    if result.masks is not None and getattr(result.masks, "xy", None) is not None:
        polygons = [pts for pts in result.masks.xy if pts is not None and len(pts) >= 3]
        if polygons:
            if result.boxes is not None and hasattr(result.boxes, "conf") and len(result.boxes.conf) == len(polygons):
                best_index = int(np.argmax(result.boxes.conf.cpu().numpy()))
            else:
                best_index = int(np.argmax([cv2.contourArea(pts.astype(np.float32)) for pts in polygons]))
            polygon = polygons[best_index].astype(np.float32) / np.array([[imgsz, imgsz]], dtype=np.float32)

    if polygon is None:
        return None

    box, _, _, _ = robust_corners_from_polygon(img_resized, polygon)
    if box is None:
        return None
    return _warp_from_box(img_resized, box, out_w=out_w)
