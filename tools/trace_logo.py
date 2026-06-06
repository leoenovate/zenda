"""Trace logo.png to mask-accurate SVG via potrace (upscaled for fidelity)."""
from __future__ import annotations

from pathlib import Path

import potrace
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "icons" / "logo.png"
OUT = ROOT / "assets" / "icons" / "logo.svg"
SCALE = 4
PAD = 2


def _path_data(path: potrace.Path, scale: float) -> str:
    parts: list[str] = []
    inv = 1.0 / scale
    for curve in path.curves:
        sx = curve.start_point.x * inv
        sy = curve.start_point.y * inv
        parts.append(f"M {sx:.3f} {sy:.3f}")
        for seg in curve.segments:
            if seg.is_corner:
                parts.append(
                    f"L {seg.c.x * inv:.3f} {seg.c.y * inv:.3f} "
                    f"L {seg.end_point.x * inv:.3f} {seg.end_point.y * inv:.3f}"
                )
            else:
                parts.append(
                    f"C {seg.c1.x * inv:.3f} {seg.c1.y * inv:.3f} "
                    f"{seg.c2.x * inv:.3f} {seg.c2.y * inv:.3f} "
                    f"{seg.end_point.x * inv:.3f} {seg.end_point.y * inv:.3f}"
                )
        parts.append("Z")
    return " ".join(parts)


def _logo_mask(arr: np.ndarray) -> np.ndarray:
    opaque = arr[:, :, 3] > 128
    blue = arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20
    return opaque & blue


def _bbox(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)
    mask = _logo_mask(arr)
    x0, y0, x1, y1 = _bbox(mask)
    x0 = max(0, x0 - PAD)
    y0 = max(0, y0 - PAD)
    x1 = min(mask.shape[1], x1 + PAD)
    y1 = min(mask.shape[0], y1 + PAD)
    crop = mask[y0:y1, x0:x1]
    cw, ch = crop.shape[1], crop.shape[0]

    # Potrace expects black shapes on white; Bitmap(bool) inverts internally.
    layer = Image.fromarray((~crop).astype(np.uint8) * 255, mode="L")
    up = layer.resize((cw * SCALE, ch * SCALE), Image.Resampling.NEAREST)

    traced = potrace.Bitmap(up).trace(
        turdsize=2,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=1.0,
        opticurve=True,
        opttolerance=0.08,
    )

    d = _path_data(traced, SCALE)
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {cw} {ch}" color="#1A5F5F" aria-hidden="true">
  <!-- Mask-traced from logo.png (potrace {SCALE}x). Tint via color or ColorFilter. -->
  <path fill="currentColor" fill-rule="evenodd" d="{d}"/>
</svg>
"""
    OUT.write_text(svg, encoding="utf-8")

    print(f"Wrote {OUT} viewBox={cw}x{ch} curves={len(traced.curves)}")


if __name__ == "__main__":
    main()
