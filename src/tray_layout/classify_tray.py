from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from src.tray_layout.tray_types import TrayTypeKey

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


@dataclass(frozen=True)
class TrayTypePrediction:
    key: TrayTypeKey
    confidence: float
    probabilities: np.ndarray

    @property
    def cols(self) -> int:
        return int(self.key[0])

    @property
    def rows(self) -> int:
        return int(self.key[1])


class TrayTypeNet(nn.Module):
    """Notebook-2 model wrapper used for inference only."""

    def __init__(self, backbone_name: str, n_classes: int):
        super().__init__()
        try:
            import timm
        except ImportError as exc:
            raise ImportError("timm is required to construct TrayTypeNet.") from exc

        self.backbone = timm.create_model(
            backbone_name,
            pretrained=True,
            num_classes=0,
            global_pool="avg",
        )
        feat = self.backbone.num_features
        self.head = nn.Linear(feat, n_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        features = self.backbone(x)
        return self.head(features)


def resize_letterbox(
    img_rgb: np.ndarray,
    out_h: int,
    out_w: int,
    fill: int = 0,
) -> tuple[np.ndarray, dict[str, float | int]]:
    """Resize with aspect ratio preserved and pad to the requested size."""
    height, width = img_rgb.shape[:2]
    scale = min(out_w / width, out_h / height)
    new_w = int(round(width * scale))
    new_h = int(round(height * scale))
    resized = cv2.resize(img_rgb, (new_w, new_h), interpolation=cv2.INTER_AREA)

    canvas = np.full((out_h, out_w, 3), fill, dtype=np.uint8)
    pad_left = (out_w - new_w) // 2
    pad_top = (out_h - new_h) // 2
    canvas[pad_top : pad_top + new_h, pad_left : pad_left + new_w] = resized
    meta = {
        "scale": scale,
        "pad_left": pad_left,
        "pad_top": pad_top,
        "new_w": new_w,
        "new_h": new_h,
    }
    return canvas, meta


def to_tensor_norm(img_rgb_uint8: np.ndarray) -> torch.Tensor:
    x = img_rgb_uint8.astype(np.float32) / 255.0
    x = (x - IMAGENET_MEAN) / IMAGENET_STD
    x = np.transpose(x, (2, 0, 1))
    return torch.tensor(x, dtype=torch.float32)


def load_tray_type_checkpoint(
    path: str | Path,
    device: str | torch.device = "cpu",
) -> tuple[TrayTypeNet, list[TrayTypeKey], dict[str, Any]]:
    checkpoint = torch.load(path, map_location=device)
    idx_to_key = [tuple(item) for item in checkpoint["idx_to_key"]]
    backbone = checkpoint.get("backbone", "resnet18")
    model = TrayTypeNet(backbone_name=backbone, n_classes=len(idx_to_key)).to(device)
    model.load_state_dict(checkpoint["model"])
    model.eval()
    return model, idx_to_key, checkpoint


@torch.no_grad()
def predict_tray_type(
    model: nn.Module,
    idx_to_key: list[TrayTypeKey],
    rectified_bgr: np.ndarray,
    input_size: tuple[int, int] = (384, 640),
    device: str | torch.device = "cpu",
) -> TrayTypePrediction:
    rgb = cv2.cvtColor(rectified_bgr, cv2.COLOR_BGR2RGB)
    rgb, _ = resize_letterbox(rgb, out_h=input_size[0], out_w=input_size[1], fill=0)
    x = to_tensor_norm(rgb).unsqueeze(0).to(device)
    logits = model(x)
    probs = F.softmax(logits, dim=1)[0].detach().cpu().numpy()
    idx = int(probs.argmax())
    return TrayTypePrediction(
        key=idx_to_key[idx],
        confidence=float(probs[idx]),
        probabilities=probs,
    )
