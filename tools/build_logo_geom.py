"""Build logo.svg from circles + straight-bar capsules (L/A path segments only)."""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "icons" / "logo.png"
OUT = ROOT / "assets" / "logos" / "logo.svg"
PAD = 1.0
BAR_HW = 9.0  # half-width of straight connectors (~18px bar)

# Node centers + radii (px in full PNG), from distance-transform peaks on logo.png.
NODES: list[tuple[float, float, float]] = [
    (293.0, 81.0, 37.0),  # top-right large
    (136.0, 123.0, 37.0),  # upper-left large (S stem)
    (225.0, 149.0, 21.0),  # center-right junction
    (205.0, 206.0, 20.0),  # center-left junction
    (291.0, 233.0, 37.0),  # bottom-right large
    (137.0, 275.0, 37.0),  # bottom-left large
]

# Two interlocking hooks (PNG has two 4-connected components + speck).
# Top hook: nodes 0,1,3; bottom hook: nodes 2,4,5.
EDGES: list[tuple[int, int]] = [
    (0, 1),  # top hook: upper bar
    (1, 3),  # top hook: lower diagonal
    (2, 4),  # bottom hook: upper diagonal
    (4, 5),  # bottom hook: lower bar
]


def _edt(mask: np.ndarray) -> np.ndarray:
    from collections import deque

    h, w = mask.shape
    d = np.full((h, w), -1, dtype=np.int32)
    q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if ny < 0 or ny >= h or nx < 0 or nx >= w or not mask[ny, nx]:
                    d[y, x] = 0
                    q.append((y, x))
                    break
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and d[ny, nx] < 0:
                d[ny, nx] = d[y, x] + 1
                q.append((ny, nx))
    d[d < 0] = 0
    return d


def _refine_nodes(mask: np.ndarray) -> list[tuple[float, float, float]]:
    """Snap NODES to local EDT maxima when close."""
    d = _edt(mask)
    h, w = mask.shape
    refined: list[tuple[float, float, float]] = []
    for cx, cy, r in NODES:
        ix, iy = int(round(cx)), int(round(cy))
        best = (ix, iy, float(d[iy, ix] if 0 <= iy < h and 0 <= ix < w else r))
        for dy in range(-6, 7):
            for dx in range(-6, 7):
                x, y = ix + dx, iy + dy
                if 0 <= x < w and 0 <= y < h and mask[y, x]:
                    v = float(d[y, x])
                    if v > best[2]:
                        best = (x, y, v)
        refined.append((best[0], best[1], best[2]))
    return refined


def _norm(x: float, y: float) -> tuple[float, float]:
    m = math.hypot(x, y)
    if m < 1e-9:
        return 0.0, 0.0
    return x / m, y / m


def _capsule_path(
    x1: float, y1: float, x2: float, y2: float, hw: float
) -> str:
    """Uniform-width bar between node centers (L/A only). Circles cover the joints."""
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    if length < 1e-6:
        return ""

    nx, ny = _norm(-dy, dx)

    p1a = (x1 + nx * hw, y1 + ny * hw)
    p1b = (x1 - nx * hw, y1 - ny * hw)
    p2a = (x2 + nx * hw, y2 + ny * hw)
    p2b = (x2 - nx * hw, y2 - ny * hw)

    def pt(p: tuple[float, float]) -> str:
        return f"{p[0]:.3f} {p[1]:.3f}"

    # Keep the same winding direction as the circle subpaths. Otherwise the
    # nonzero fill rule subtracts the overlap and carves wedges from the nodes.
    return (
        f"M {pt(p1a)} "
        f"A {hw:.3f} {hw:.3f} 0 0 0 {pt(p1b)} "
        f"L {pt(p2b)} "
        f"A {hw:.3f} {hw:.3f} 0 0 0 {pt(p2a)} "
        f"L {pt(p1a)} Z"
    )


def _circle_path(cx: float, cy: float, r: float) -> str:
    """Circle from two semicircular arcs (no cubics)."""
    return (
        f"M {cx - r:.3f} {cy:.3f} "
        f"A {r:.3f} {r:.3f} 0 0 1 {cx + r:.3f} {cy:.3f} "
        f"A {r:.3f} {r:.3f} 0 0 1 {cx - r:.3f} {cy:.3f} Z"
    )


def _shape_bounds(nodes: list[tuple[float, float, float]]) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []
    for cx, cy, r in nodes:
        xs.extend((cx - r, cx + r))
        ys.extend((cy - r, cy + r))
    return min(xs), min(ys), max(xs), max(ys)


def main() -> None:
    arr = np.array(Image.open(SRC).convert("RGBA"))
    mask = (arr[:, :, 3] > 128) & (arr[:, :, 2].astype(int) - arr[:, :, 0].astype(int) > 20)
    nodes = _refine_nodes(mask)

    parts: list[str] = []
    for cx, cy, r in nodes:
        parts.append(_circle_path(cx, cy, r))
    for i, j in EDGES:
        x1, y1, _ = nodes[i]
        x2, y2, _ = nodes[j]
        seg = _capsule_path(x1, y1, x2, y2, BAR_HW)
        if seg:
            parts.append(seg)

    min_x, min_y, max_x, max_y = _shape_bounds(nodes)
    min_x -= PAD
    min_y -= PAD
    max_x += PAD
    max_y += PAD
    vw, vh = max_x - min_x, max_y - min_y

    d = " ".join(parts)
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="{min_x:.1f} {min_y:.1f} {vw:.1f} {vh:.1f}" color="#1A5F5F" aria-hidden="true">
  <!-- Geometric logo: circles + line/arc capsules. Tint via currentColor. -->
  <path fill="currentColor" fill-rule="nonzero" d="{d}"/>
</svg>
"""
    OUT.write_text(svg, encoding="utf-8")
    print(f"Wrote {OUT} viewBox={vw:.1f}x{vh:.1f} nodes={len(nodes)} edges={len(EDGES)}")


if __name__ == "__main__":
    main()
