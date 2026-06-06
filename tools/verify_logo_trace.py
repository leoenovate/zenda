"""Compare potrace SVG mask against source logo.png crop."""
from __future__ import annotations

from pathlib import Path

import potrace
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "icons" / "logo.png"
SVG = ROOT / "assets" / "icons" / "logo.svg"
SCALE = 4
PAD = 2


def logo_mask(arr: np.ndarray) -> np.ndarray:
    opaque = arr[:, :, 3] > 128
    blue = arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20
    return opaque & blue


def rasterize_potrace(mask: np.ndarray) -> np.ndarray:
    ch, cw = mask.shape
    layer = Image.fromarray((~mask).astype(np.uint8) * 255, mode="L")
    up = layer.resize((cw * SCALE, ch * SCALE), Image.Resampling.NEAREST)
    path = potrace.Bitmap(up).trace(
        turdsize=2,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=1.0,
        opticurve=True,
        opttolerance=0.08,
    )

    result = np.zeros((ch, cw), dtype=bool)
    inv = 1.0 / SCALE

    for curve in path.curves:
        pts: list[tuple[float, float]] = [
            (curve.start_point.x * inv, curve.start_point.y * inv)
        ]
        for seg in curve.segments:
            if seg.is_corner:
                pts.append((seg.c.x * inv, seg.c.y * inv))
                pts.append((seg.end_point.x * inv, seg.end_point.y * inv))
            else:
                p0 = pts[-1]
                p1 = (seg.c1.x * inv, seg.c1.y * inv)
                p2 = (seg.c2.x * inv, seg.c2.y * inv)
                p3 = (seg.end_point.x * inv, seg.end_point.y * inv)
                for t in np.linspace(0, 1, 16)[1:]:
                    t = float(t)
                    x = (
                        (1 - t) ** 3 * p0[0]
                        + 3 * (1 - t) ** 2 * t * p1[0]
                        + 3 * (1 - t) * t**2 * p2[0]
                        + t**3 * p3[0]
                    )
                    y = (
                        (1 - t) ** 3 * p0[1]
                        + 3 * (1 - t) ** 2 * t * p1[1]
                        + 3 * (1 - t) * t**2 * p2[1]
                        + t**3 * p3[1]
                    )
                    pts.append((x, y))
        if len(pts) < 3:
            continue
        layer_img = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(layer_img).polygon(pts, fill=255)
        result ^= np.array(layer_img) > 0
    return result


def main() -> None:
    arr = np.array(Image.open(SRC).convert("RGBA"))
    mask = logo_mask(arr)
    ys, xs = np.where(mask)
    x0, y0 = max(0, int(xs.min()) - PAD), max(0, int(ys.min()) - PAD)
    x1, y1 = min(mask.shape[1], int(xs.max()) + 1 + PAD), min(
        mask.shape[0], int(ys.max()) + 1 + PAD
    )
    crop = mask[y0:y1, x0:x1]
    approx = rasterize_potrace(crop)
    inter = (crop & approx).sum()
    union = (crop | approx).sum()
    miss = (crop & ~approx).sum()
    extra = (~crop & approx).sum()
    print(f"crop {crop.shape[1]}x{crop.shape[0]}")
    print(f"iou={inter/union:.4f} miss={miss} extra={extra}")
    svg = SVG.read_text(encoding="utf-8")
    assert "d=\"" in svg
    print("svg bytes", len(svg))


if __name__ == "__main__":
    main()
