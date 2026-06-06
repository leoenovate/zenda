"""Compare geometric logo.svg against logo.png mask."""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "icons" / "logo.png"
SVG = ROOT / "assets" / "logos" / "logo.svg"
PAD = 2


def logo_mask(arr: np.ndarray) -> np.ndarray:
    opaque = arr[:, :, 3] > 128
    blue = arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20
    return opaque & blue


def rasterize_path(d: str, offset_x: float, offset_y: float, size: tuple[int, int]) -> np.ndarray:
    cw, ch = size
    result = np.zeros((ch, cw), dtype=bool)

    def draw_polygon(pts: list[tuple[float, float]]) -> None:
        if len(pts) < 3:
            return
        layer = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(layer).polygon(pts, fill=255)
        nonlocal result
        result |= np.array(layer) > 0

    toks = d.split()
    pts: list[tuple[float, float]] = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t == "M":
            if len(pts) >= 3:
                draw_polygon(pts)
            pts = [(float(toks[i + 1]) + offset_x, float(toks[i + 2]) + offset_y)]
            i += 3
        elif t == "L":
            pts.append((float(toks[i + 1]) + offset_x, float(toks[i + 2]) + offset_y))
            i += 3
        elif t == "A":
            rx, ry = float(toks[i + 1]), float(toks[i + 2])
            x, y = float(toks[i + 6]), float(toks[i + 7])
            if len(pts) >= 1:
                p0 = pts[-1]
                p1 = (x + offset_x, y + offset_y)
                cx = (p0[0] + p1[0]) / 2
                cy = (p0[1] + p1[1]) / 2
                r = max(rx, ry)
                for k in np.linspace(0, 1, 24)[1:-1]:
                    ang0 = np.arctan2(p0[1] - cy, p0[0] - cx)
                    ang1 = np.arctan2(p1[1] - cy, p1[0] - cx)
                    ang = ang0 + (ang1 - ang0) * k
                    pts.append((cx + r * np.cos(ang), cy + r * np.sin(ang)))
            pts.append((x + offset_x, y + offset_y))
            i += 8
        elif t == "Z":
            if len(pts) >= 3:
                draw_polygon(pts)
            pts = []
            i += 1
        else:
            i += 1
    if len(pts) >= 3:
        draw_polygon(pts)
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
    cw, ch = crop.shape[1], crop.shape[0]

    svg = SVG.read_text(encoding="utf-8")
    m = re.search(r'd="([^"]+)"', svg)
    assert m, "missing path d"
    d = m.group(1)
    full = rasterize_path(d, 0, 0, (mask.shape[1], mask.shape[0]))
    approx = full[y0:y1, x0:x1]

    inter = (crop & approx).sum()
    union = (crop | approx).sum()
    print(f"crop {cw}x{ch}")
    print(f"iou={inter/union:.4f} miss={(crop & ~approx).sum()} extra={(~crop & approx).sum()}")
    assert " C " not in f" {d} "
    print("segments: lines+arcs only")


if __name__ == "__main__":
    main()
