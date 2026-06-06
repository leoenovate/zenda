"""Export potrace curve previews for inspection."""
from __future__ import annotations

import potrace
import numpy as np
from PIL import Image, ImageDraw

SRC = r"c:\i\zenda\assets\icons\logo.png"
OUT_DIR = r"c:\i\zenda\assets\icons"
SCALE = 4
PAD = 2


def logo_mask(arr: np.ndarray) -> np.ndarray:
    return (arr[:, :, 3] > 128) & (
        arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20
    )


def curve_polys(curve, scale: float, ox: float, oy: float) -> list[tuple[float, float]]:
    inv = 1.0 / scale
    pts = [(curve.start_point.x * inv - ox, curve.start_point.y * inv - oy)]
    for seg in curve.segments:
        if seg.is_corner:
            pts.append((seg.c.x * inv - ox, seg.c.y * inv - oy))
            pts.append((seg.end_point.x * inv - ox, seg.end_point.y * inv - oy))
        else:
            p0 = pts[-1]
            p1 = (seg.c1.x * inv - ox, seg.c1.y * inv - oy)
            p2 = (seg.c2.x * inv - ox, seg.c2.y * inv - oy)
            p3 = (seg.end_point.x * inv - ox, seg.end_point.y * inv - oy)
            for t in np.linspace(0, 1, 20)[1:]:
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
    return pts


def main() -> None:
    arr = np.array(Image.open(SRC).convert("RGBA"))
    mask = logo_mask(arr)
    ys, xs = np.where(mask)
    x0, y0 = max(0, int(xs.min()) - PAD), max(0, int(ys.min()) - PAD)
    x1, y1 = min(mask.shape[1], int(xs.max()) + 1 + PAD), min(
        mask.shape[0], int(ys.max()) + 1 + PAD
    )
    cw, ch = x1 - x0, y1 - y0
    crop = mask[y0:y1, x0:x1]

    up = np.array(
        Image.fromarray((mask.astype(np.uint8) * 255)).resize(
            (mask.shape[1] * SCALE, mask.shape[0] * SCALE), Image.Resampling.NEAREST
        )
    ) > 127
    path = potrace.Bitmap(up).trace(
        turdsize=0,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=1.0,
        opticurve=True,
        opttolerance=0.05,
    )

    # Reference crop
    Image.fromarray((crop.astype(np.uint8) * 255)).save(f"{OUT_DIR}/_ref_crop.png")

    for idx in range(len(path.curves)):
        layer = np.zeros((ch, cw), dtype=bool)
        img = Image.new("L", (cw, ch), 0)
        draw = ImageDraw.Draw(img)
        poly = curve_polys(path.curves[idx], SCALE, x0, y0)
        if len(poly) >= 3:
            draw.polygon(poly, fill=255)
        img.save(f"{OUT_DIR}/_curve_{idx}.png")

    # Combined evenodd curves 2+3 only
    combo = Image.new("L", (cw, ch), 0)
    result = np.zeros((ch, cw), dtype=bool)
    for idx in (2, 3):
        poly = curve_polys(path.curves[idx], SCALE, x0, y0)
        if len(poly) < 3:
            continue
        layer = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(layer).polygon(poly, fill=255)
        result ^= np.array(layer) > 0
    Image.fromarray((result.astype(np.uint8) * 255)).save(f"{OUT_DIR}/_combo_23.png")

    inter = (crop & result).sum()
    union = (crop | result).sum()
    print(f"combo23 iou={inter/union:.4f} miss={(crop & ~result).sum()} extra={(~crop & result).sum()}")


if __name__ == "__main__":
    main()
