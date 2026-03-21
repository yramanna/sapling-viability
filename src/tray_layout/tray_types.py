from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping

TrayTypeKey = tuple[int, int, int, int]


@dataclass(frozen=True)
class TrayTypeSpec:
    cols: int
    rows: int
    warp_width: int = 0
    warp_height: int = 0

    @classmethod
    def from_key(cls, key: TrayTypeKey) -> "TrayTypeSpec":
        cols, rows, warp_width, warp_height = key
        return cls(cols=cols, rows=rows, warp_width=warp_width, warp_height=warp_height)

    @classmethod
    def from_label(cls, label: Mapping[str, Any]) -> "TrayTypeSpec":
        return cls.from_key(type_key_from_label(label))

    def key(self) -> TrayTypeKey:
        return (self.cols, self.rows, self.warp_width, self.warp_height)


def type_key_from_label(label: Mapping[str, Any]) -> TrayTypeKey:
    cols = int(label["cols"])
    rows = int(label["rows"])
    warp_size = label.get("warp_size", {}) if isinstance(label, Mapping) else {}
    warp_width = int(warp_size.get("w", 0))
    warp_height = int(warp_size.get("h", 0))
    return (cols, rows, warp_width, warp_height)


def pretty_key(key: TrayTypeKey) -> str:
    cols, rows, warp_width, warp_height = key
    return f"{cols}x{rows} @ {warp_width}x{warp_height}"
