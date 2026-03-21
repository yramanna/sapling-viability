from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from scipy.ndimage import median_filter


def smooth_1d(x: np.ndarray, k: int) -> np.ndarray:
    """Simple moving-average smoothing for 1D projections."""
    k = int(k)
    if k < 3:
        return x.astype(np.float32)
    if k % 2 == 0:
        k += 1
    kernel = np.ones(k, np.float32) / float(k)
    return np.convolve(x.astype(np.float32), kernel, mode="same")


def separator_mask_graytray_refined(
    warped_bgr: np.ndarray,
    debug_dir: str | Path | None = None,
    debug_prefix: str | None = None,
) -> np.ndarray:
    """Return a binary mask (0/255) of likely grey tray-plastic pixels.

    Uses:
    - Lab chroma neutrality
    - HSV saturation
    - lightness constraints
    - vegetation suppression
    - morphological cleanup

    Parameters
    ----------
    warped_bgr:
        Rectified top-down tray image in BGR format.
    debug_dir:
        Optional directory for saving debug outputs.
    debug_prefix:
        Filename prefix for debug outputs.

    Returns
    -------
    np.ndarray
        Binary uint8 mask with white pixels indicating likely separator/tray-plastic evidence.
    """
    lab = cv2.cvtColor(warped_bgr, cv2.COLOR_BGR2LAB)
    L, a, b = cv2.split(lab)

    hsv = cv2.cvtColor(warped_bgr, cv2.COLOR_BGR2HSV)
    _, S, _ = cv2.split(hsv)

    a16 = a.astype(np.int16)
    b16 = b.astype(np.int16)
    neutral = np.sqrt((a16 - 128) ** 2 + (b16 - 128) ** 2).astype(np.float32)

    Lf = L.astype(np.float32)
    Sf = S.astype(np.float32)

    score = neutral + 0.6 * Sf + 0.15 * np.abs(Lf - 120.0)
    threshold = np.percentile(score, 25)

    mask = (score <= threshold).astype(np.uint8) * 255
    mask[neutral > 35] = 0
    mask[L < 70] = 0
    mask[S > 60] = 0
    mask[L > 200] = 0

    # Extra vegetation rejection
    Bc, Gc, Rc = cv2.split(warped_bgr)
    Bf = Bc.astype(np.int16)
    Gf = Gc.astype(np.int16)
    Rf = Rc.astype(np.int16)

    exg = (2 * Gf - Rf - Bf).astype(np.int16)
    exg_threshold = np.percentile(exg, 70)
    vegetation = (exg > exg_threshold) & (Gc > Rc + 3) & (Gc > Bc + 3)
    mask[vegetation] = 0

    # Remove pixels deep inside blobs
    # inside = (mask > 0).astype(np.uint8)
    # dist_in = cv2.distanceTransform(inside, cv2.DIST_L2, 3)
    # mask[dist_in > 35.0] = 0

    soilish = ((b.astype(np.int16) - 128) > 15) & (L > 70)
    mask[soilish] = 0

    brown = (b.astype(np.int16) > 124) & (a.astype(np.int16) > 130) & (L > 60)
    mask[brown] = 0

    green_a = (a.astype(np.int16) < 124) & (L > 80)
    mask[green_a] = 0

    mask = median_filter(mask, size=3).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8), iterations=1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8), iterations=2)

    num, labels, stats, _ = cv2.connectedComponentsWithStats((mask > 0).astype(np.uint8), 8)
    height, width = mask.shape[:2]
    min_area = int(0.00001 * height * width)

    clean = np.zeros_like(mask)
    for component_id in range(1, num):
        if stats[component_id, cv2.CC_STAT_AREA] >= min_area:
            clean[labels == component_id] = 255

    if debug_dir is not None and debug_prefix:
        debug_path = Path(debug_dir)
        debug_path.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(debug_path / f"{debug_prefix}_sep_mask_graytray.jpg"), clean)

    return clean


def extract_separator_longlines(
    bin_mask_u8: np.ndarray,
    k_frac: float = 0.025,
    preclose: int = 15,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Build directional separator evidence from a binary tray-separator mask.

    Parameters
    ----------
    bin_mask_u8:
        Binary uint8 mask where white indicates tray/separator evidence.
    k_frac:
        Fraction of image width/height used to size directional kernels.
    preclose:
        Closing kernel size used before directional morphology.

    Returns
    -------
    tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]
        (lines, horiz, vert, preclosed), all uint8 0/255.
    """
    height, width = bin_mask_u8.shape[:2]
    mask = bin_mask_u8.copy()

    kernel_size = max(3, int(preclose))
    if kernel_size % 2 == 0:
        kernel_size += 1

    preclosed = cv2.morphologyEx(
        mask,
        cv2.MORPH_CLOSE,
        np.ones((kernel_size, kernel_size), np.uint8),
        iterations=1,
    )

    kx = max(15, int(width * float(k_frac)))
    ky = max(15, int(height * float(k_frac)))
    if kx % 2 == 0:
        kx += 1
    if ky % 2 == 0:
        ky += 1

    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kx, 1))
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, ky))

    horiz = cv2.morphologyEx(preclosed, cv2.MORPH_CLOSE, h_kernel, iterations=1)
    vert = cv2.morphologyEx(preclosed, cv2.MORPH_CLOSE, v_kernel, iterations=1)

    small = np.ones((3, 3), np.uint8)
    horiz = cv2.morphologyEx(horiz, cv2.MORPH_OPEN, small, iterations=1)
    vert = cv2.morphologyEx(vert, cv2.MORPH_OPEN, small, iterations=1)

    lines = cv2.bitwise_or(horiz, vert)
    lines = cv2.morphologyEx(lines, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8), iterations=1)

    return lines, horiz, vert, preclosed
