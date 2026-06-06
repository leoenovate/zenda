"""Trace logo.png to mask-accurate SVG via potrace (upscaled for fidelity)."""
from __future__ import annotations

from pathlib import Path

import potrace
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "icons" / "logo.png"
OUT = ROOT / "assets" / "logos" / "logo.svg"
SCALE = 8
PAD = 2
OUTER_PAD = 1
CURVE_PAD = 2
# Softens pixel stair-steps before curve fitting; keeps IoU ~0.968.
BLUR_RADIUS = 1.5
OPTTOLERANCE = 0.65
# Drop Potrace dust specks (px in output space); main logo contours are ~230×186.
MIN_CURVE_BBOX = 4.0


def _curve_bounds(curve: potrace.Curve, scale: float) -> tuple[float, float, float, float]:
    inv = 1.0 / scale
    xs = [curve.start_point.x * inv]
    ys = [curve.start_point.y * inv]
    for seg in curve.segments:
        if seg.is_corner:
            xs.extend((seg.c.x * inv, seg.end_point.x * inv))
            ys.extend((seg.c.y * inv, seg.end_point.y * inv))
        else:
            xs.extend((seg.c1.x * inv, seg.c2.x * inv, seg.end_point.x * inv))
            ys.extend((seg.c1.y * inv, seg.c2.y * inv, seg.end_point.y * inv))
    return min(xs), min(ys), max(xs), max(ys)


def _keep_curves(curves: list[potrace.Curve], scale: float) -> list[potrace.Curve]:
    kept: list[potrace.Curve] = []
    for curve in curves:
        min_x, min_y, max_x, max_y = _curve_bounds(curve, scale)
        if max(max_x - min_x, max_y - min_y) >= MIN_CURVE_BBOX:
            kept.append(curve)
    return kept


def _path_data(curves: list[potrace.Curve], scale: float, tx: float, ty: float) -> str:
    parts: list[str] = []
    inv = 1.0 / scale
    for curve in curves:
        sx = curve.start_point.x * inv + tx
        sy = curve.start_point.y * inv + ty
        parts.append(f"M {sx:.3f} {sy:.3f}")
        for seg in curve.segments:
            if seg.is_corner:
                parts.append(
                    f"L {seg.c.x * inv + tx:.3f} {seg.c.y * inv + ty:.3f} "
                    f"L {seg.end_point.x * inv + tx:.3f} {seg.end_point.y * inv + ty:.3f}"
                )
            else:
                parts.append(
                    f"C {seg.c1.x * inv + tx:.3f} {seg.c1.y * inv + ty:.3f} "
                    f"{seg.c2.x * inv + tx:.3f} {seg.c2.y * inv + ty:.3f} "
                    f"{seg.end_point.x * inv + tx:.3f} {seg.end_point.y * inv + ty:.3f}"
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


def _path_bounds(curves: list[potrace.Curve], scale: float) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []
    for curve in curves:
        min_x, min_y, max_x, max_y = _curve_bounds(curve, scale)
        xs.extend((min_x, max_x))
        ys.extend((min_y, max_y))
    return min(xs), min(ys), max(xs), max(ys)


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
    up = layer.resize((cw * SCALE, ch * SCALE), Image.Resampling.LANCZOS)
    if BLUR_RADIUS > 0:
        up = up.filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS))

    traced = potrace.Bitmap(up).trace(
        turdsize=2,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=1.334,
        opticurve=True,
        opttolerance=OPTTOLERANCE,
    )

    curves = _keep_curves(list(traced.curves), SCALE)

    min_x, min_y, max_x, max_y = _path_bounds(curves, SCALE)
    min_x -= CURVE_PAD
    min_y -= CURVE_PAD
    max_x += CURVE_PAD
    max_y += CURVE_PAD
    pw, ph = max_x - min_x, max_y - min_y
    vw = pw + 2 * OUTER_PAD
    vh = ph + 2 * OUTER_PAD
    tx = OUTER_PAD - min_x
    ty = OUTER_PAD - min_y

    d = _path_data(curves, SCALE, tx, ty)
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vw:.1f} {vh:.1f}" color="#1A5F5F" aria-hidden="true">
  <!-- Mask-traced from logo.png (potrace {SCALE}x, blur={BLUR_RADIUS}, trimmed). Tint via currentColor. -->
  <path fill="currentColor" fill-rule="evenodd" d="{d}"/>
</svg>
"""
    OUT.write_text(svg, encoding="utf-8")

    print(f"Wrote {OUT} viewBox={vw:.1f}x{vh:.1f} curves={len(curves)}")


if __name__ == "__main__":
    main()
