from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import models

from src.germination.transforms import get_validity_inference_transform

DEFAULT_VALIDITY_CLASS_NAMES = ("empty", "occupied")


@dataclass(frozen=True)
class CellValidityPrediction:
    cell_id: str
    prediction: str
    confidence: float
    class_index: int
    crop_path: str


def _default_device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    if torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def load_validity_model(
    model_path: str | Path,
    device: str | torch.device | None = None,
) -> tuple[torch.nn.Module, torch.device]:
    """Load the ResNet18 validity model from the notebook checkpoint."""
    resolved_device = torch.device(device) if device is not None else _default_device()
    model = models.resnet18(weights=None)
    model.fc = nn.Linear(model.fc.in_features, 2)
    state_dict = torch.load(Path(model_path), map_location=resolved_device)
    model.load_state_dict(state_dict)
    model.to(resolved_device)
    model.eval()
    return model, resolved_device


def predict_validity_for_crop(
    crop_path: str | Path,
    model: torch.nn.Module,
    device: str | torch.device | None = None,
    class_names: Sequence[str] = DEFAULT_VALIDITY_CLASS_NAMES,
) -> CellValidityPrediction:
    """Run notebook-style validity inference for one cropped cell image."""
    resolved_device = torch.device(device) if device is not None else next(model.parameters()).device
    transform = get_validity_inference_transform()
    crop_path = Path(crop_path)

    image = Image.open(crop_path).convert("RGB")
    input_tensor = transform(image).unsqueeze(0).to(resolved_device)

    with torch.no_grad():
        logits = model(input_tensor)
        probs = F.softmax(logits, dim=1)
        confidence, pred = torch.max(probs, 1)

    pred_index = int(pred.item())
    return CellValidityPrediction(
        cell_id=crop_path.name,
        prediction=class_names[pred_index],
        confidence=float(confidence.item()),
        class_index=pred_index,
        crop_path=str(crop_path),
    )


def predict_validity_for_tray(
    crop_paths: Sequence[str | Path],
    model: torch.nn.Module,
    device: str | torch.device | None = None,
    class_names: Sequence[str] = DEFAULT_VALIDITY_CLASS_NAMES,
) -> list[CellValidityPrediction]:
    """Run validity inference across all cropped cells for a tray."""
    return [
        predict_validity_for_crop(crop_path, model=model, device=device, class_names=class_names)
        for crop_path in sorted(crop_paths, key=lambda p: Path(p).name)
    ]


def summarize_tray_validity(predictions: Sequence[CellValidityPrediction]) -> dict[str, float | int]:
    """Aggregate per-cell validity predictions into tray viability stats."""
    total_cells = len(predictions)
    occupied_count = sum(1 for pred in predictions if pred.prediction == "occupied")
    empty_count = total_cells - occupied_count
    viability_pct = (occupied_count / total_cells) * 100.0 if total_cells else 0.0

    mean_occupied_confidence = (
        sum(pred.confidence for pred in predictions if pred.prediction == "occupied") / occupied_count
        if occupied_count
        else 0.0
    )
    mean_empty_confidence = (
        sum(pred.confidence for pred in predictions if pred.prediction == "empty") / empty_count
        if empty_count
        else 0.0
    )

    return {
        "total_cells": total_cells,
        "occupied_count": occupied_count,
        "empty_count": empty_count,
        "viability_pct": viability_pct,
        "mean_occupied_confidence": mean_occupied_confidence,
        "mean_empty_confidence": mean_empty_confidence,
    }


def predict_tray_validity_stats(
    crop_paths: Sequence[str | Path],
    model_path: str | Path,
    device: str | torch.device | None = None,
    class_names: Sequence[str] = DEFAULT_VALIDITY_CLASS_NAMES,
) -> tuple[list[CellValidityPrediction], dict[str, float | int]]:
    """Convenience wrapper: load checkpoint, predict all cells, return tray stats."""
    model, resolved_device = load_validity_model(model_path=model_path, device=device)
    predictions = predict_validity_for_tray(
        crop_paths=crop_paths,
        model=model,
        device=resolved_device,
        class_names=class_names,
    )
    stats = summarize_tray_validity(predictions)
    return predictions, stats
