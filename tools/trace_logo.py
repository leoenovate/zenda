"""Trace logo.png to mask-accurate SVG via potrace (upscaled for fidelity)."""
from __future__ import annotations

import potrace
import numpy as np
from PIL import Image

SRC = r"c:\i\zenda\assets\icons\logo.png"
OUT = r"c:\i\zenda\assets\icons\logo.svg"
SCALE = 4
PAD = 2


def _path_data(path: potrace.Path, scale: float, ox: float, oy: float) -> str:
    parts: list[str] = []
    inv = 1.0 / scale
    for curve in path.curves:
        sx = curve.start_point.x * inv - ox
        sy = curve.start_point.y * inv - oy
        parts.append(f"M {sx:.3f} {sy:.3f}")
        for seg in curve.segments:
            if seg.is_corner:
                parts.append(
                    f"L {seg.c.x * inv - ox:.3f} {seg.c.y * inv - oy:.3f} "
                    f"L {seg.end_point.x * inv - ox:.3f} {seg.end_point.y * inv - oy:.3f}"
                )
            else:
                parts.append(
                    f"C {seg.c1.x * inv - ox:.3f} {seg.c1.y * inv - oy:.3f} "
                    f"{seg.c2.x * inv - ox:.3f} {seg.c2.y * inv - oy:.3f} "
                    f"{seg.end_point.x * inv - ox:.3f} {seg.end_point.y * inv - oy:.3f}"
                )
        parts.append("Z")
    return " ".join(parts)


def _logo_mask(arr: np.ndarray) -> np.ndarray:
    return (arr[:, :, 3] > 128) & (
        arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20
    )


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
    cw, ch = x1 - x0, y1 - y0

    up = Image.fromarray((mask.astype(np.uint8) * 255)).resize(
        (mask.shape[1] * SCALE, mask.shape[0] * SCALE), Image.Resampling.NEAREST
    )
    up_mask = np.array(up) > 127

    traced = potrace.Bitmap(up_mask).trace(
        turdsize=0,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=1.0,
        opticurve=True,
        opttolerance=0.05,
    )

    d = _path_data(traced, SCALE, x0, y0)
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {cw} {ch}" color="#1A5F5F" aria-hidden="true">
  <!-- Mask-traced from logo.png (potrace {SCALE}x). Tint via color or ColorFilter. -->
  <path fill="currentColor" fill-rule="evenodd" d="{d}"/>
</svg>
"""
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(svg)

    print(f"Wrote {OUT} viewBox={cw}x{ch} curves={len(traced.curves)}")


if __name__ == "__main__":
    main()
