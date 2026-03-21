from __future__ import annotations

import cv2
import numpy as np


def order_points_tl_tr_br_bl(pts: np.ndarray) -> np.ndarray:
    """Order four points as top-left, top-right, bottom-right, bottom-left."""
    pts = np.asarray(pts, dtype=np.float32)
    sums = pts.sum(axis=1)
    diffs = np.diff(pts, axis=1).reshape(-1)
    top_left = pts[np.argmin(sums)]
    bottom_right = pts[np.argmax(sums)]
    top_right = pts[np.argmin(diffs)]
    bottom_left = pts[np.argmax(diffs)]
    return np.array([top_left, top_right, bottom_right, bottom_left], dtype=np.float32)


def _polygon_to_image_coords(img_bgr: np.ndarray, polygon_xy: np.ndarray) -> np.ndarray:
    height, width = img_bgr.shape[:2]
    polygon_xy = np.asarray(polygon_xy, dtype=np.float32)
    if polygon_xy.size == 0:
        return polygon_xy.reshape(0, 2)

    if polygon_xy.max() <= 1.5:
        scale = np.array([[width, height]], dtype=np.float32)
        return polygon_xy * scale
    return polygon_xy


def robust_corners_from_polygon(
    img_bgr: np.ndarray,
    polygon_xy: np.ndarray,
) -> tuple[np.ndarray | None, np.ndarray | None, np.ndarray | None, tuple | None]:
    """
    Convert a tray polygon into an ordered 4-corner box suitable for warping.

    Returns `(box, contour, approx, rect)`. `box` is `None` if the polygon is unusable.
    """
    contour = _polygon_to_image_coords(img_bgr, polygon_xy)
    if contour.shape[0] < 3:
        return None, None, None, None

    contour = contour.reshape(-1, 1, 2).astype(np.float32)
    rect = cv2.minAreaRect(contour)
    box = cv2.boxPoints(rect).astype(np.float32)

    peri = cv2.arcLength(contour, True)
    approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
    if len(approx) == 4:
        box = approx.reshape(4, 2).astype(np.float32)

    return order_points_tl_tr_br_bl(box), contour.reshape(-1, 2), approx.reshape(-1, 2), rect
