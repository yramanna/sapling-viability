from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

from src.rectification import predict_and_crop


class _DummyConf:
    def __init__(self, values: list[float]) -> None:
        self._values = np.array(values, dtype=np.float32)

    def cpu(self) -> "_DummyConf":
        return self

    def numpy(self) -> np.ndarray:
        return self._values

    def __len__(self) -> int:
        return len(self._values)


class _DummyBoxes:
    def __init__(self, confs: list[float]) -> None:
        self.conf = _DummyConf(confs)


class _DummyMasks:
    def __init__(self, polygons: list[np.ndarray]) -> None:
        self.xy = polygons


class _DummyResult:
    def __init__(self, polygons: list[np.ndarray] | None, confs: list[float] | None = None) -> None:
        self.masks = None if polygons is None else _DummyMasks(polygons)
        self.boxes = None if confs is None else _DummyBoxes(confs)


class _DummyModel:
    def __init__(self, result: _DummyResult) -> None:
        self._result = result

    def predict(self, **_: object) -> list[_DummyResult]:
        return [self._result]


def test_predict_and_crop_returns_none_when_image_missing() -> None:
    model = _DummyModel(_DummyResult(polygons=None))

    assert predict_and_crop("does_not_exist.jpg", model=model) is None


def test_predict_and_crop_warps_best_polygon() -> None:
    img = np.full((240, 320, 3), 255, dtype=np.uint8)
    cv2.rectangle(img, (80, 60), (240, 180), (0, 180, 0), -1)
    polygon = np.array([[256, 256], [768, 256], [768, 768], [256, 768]], dtype=np.float32)
    model = _DummyModel(_DummyResult(polygons=[polygon], confs=[0.95]))

    cropped = predict_and_crop(img, model=model, out_w=200, imgsz=1024)

    assert cropped is not None
    assert cropped.shape[1] == 200
    assert cropped.shape[0] > 0
    assert cropped.mean() < 255


def test_predict_and_crop_accepts_path_input(tmp_path: Path) -> None:
    img = np.full((200, 300, 3), 255, dtype=np.uint8)
    cv2.rectangle(img, (75, 50), (225, 150), (30, 30, 200), -1)
    img_path = tmp_path / "tray.jpg"
    cv2.imwrite(str(img_path), img)

    polygon = np.array([[256, 256], [768, 256], [768, 768], [256, 768]], dtype=np.float32)
    model = _DummyModel(_DummyResult(polygons=[polygon]))

    cropped = predict_and_crop(img_path, model=model, out_w=160, imgsz=1024)

    assert cropped is not None
    assert cropped.shape[1] == 160


def test_predict_and_crop_returns_none_without_masks() -> None:
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    model = _DummyModel(_DummyResult(polygons=None))

    assert predict_and_crop(img, model=model) is None
