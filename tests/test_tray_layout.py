from __future__ import annotations

"""Tests for tray-type preprocessing, inference helpers, and route selection."""

import numpy as np
import torch

from src.tray_layout.classify_tray import predict_tray_type, resize_letterbox, to_tensor_norm
from src.tray_layout.routing import choose_layout_route
from src.tray_layout.tray_types import TrayTypeSpec, pretty_key, type_key_from_label


class _DummyModel(torch.nn.Module):
    """Minimal classifier stub that returns fixed logits for every input."""

    def __init__(self, logits: list[float]) -> None:
        super().__init__()
        self._logits = torch.tensor([logits], dtype=torch.float32)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self._logits.repeat(x.shape[0], 1)


def test_choose_layout_route_uses_classifier_when_confidence_above_threshold() -> None:
    result = choose_layout_route(confidence=0.96, threshold=0.95)

    assert result.use_classifier_layout is True
    assert result.confidence == 0.96
    assert result.threshold == 0.95
    assert "above threshold" in result.reason


def test_choose_layout_route_uses_classifier_when_confidence_equals_threshold() -> None:
    result = choose_layout_route(confidence=0.95, threshold=0.95)

    assert result.use_classifier_layout is True
    assert result.confidence == 0.95
    assert result.threshold == 0.95
    assert "above threshold" in result.reason


def test_choose_layout_route_uses_cv_fallback_when_confidence_below_threshold() -> None:
    result = choose_layout_route(confidence=0.94, threshold=0.95)

    assert result.use_classifier_layout is False
    assert result.confidence == 0.94
    assert result.threshold == 0.95
    assert "CV fallback" in result.reason


def test_type_key_from_label_reads_warp_size() -> None:
    label = {"cols": 6, "rows": 12, "warp_size": {"w": 1400, "h": 700}}

    assert type_key_from_label(label) == (6, 12, 1400, 700)
    assert pretty_key((6, 12, 1400, 700)) == "6x12 @ 1400x700"
    assert TrayTypeSpec.from_label(label).key() == (6, 12, 1400, 700)


def test_resize_letterbox_preserves_aspect_ratio() -> None:
    img = np.zeros((20, 40, 3), dtype=np.uint8)

    resized, meta = resize_letterbox(img, out_h=100, out_w=100, fill=7)

    assert resized.shape == (100, 100, 3)
    assert meta["new_w"] == 100
    assert meta["new_h"] == 50
    assert meta["pad_top"] == 25
    assert int(resized[0, 0, 0]) == 7


def test_to_tensor_norm_returns_chw_tensor() -> None:
    img = np.zeros((10, 20, 3), dtype=np.uint8)

    tensor = to_tensor_norm(img)

    assert tuple(tensor.shape) == (3, 10, 20)
    assert tensor.dtype == torch.float32


def test_predict_tray_type_returns_top_class_and_confidence() -> None:
    img = np.full((120, 180, 3), 255, dtype=np.uint8)
    idx_to_key = [(6, 12, 1400, 700), (7, 10, 1400, 900)]
    model = _DummyModel([0.1, 3.0])

    prediction = predict_tray_type(
        model=model,
        idx_to_key=idx_to_key,
        rectified_bgr=img,
        input_size=(64, 64),
        device="cpu",
    )

    assert prediction.key == (7, 10, 1400, 900)
    assert prediction.cols == 7
    assert prediction.rows == 10
    assert 0.0 < prediction.confidence < 1.0
    assert prediction.probabilities.shape == (2,)
