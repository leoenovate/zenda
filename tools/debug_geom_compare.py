import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_logo_geom import logo_mask, rasterize_path

ROOT = Path(__file__).resolve().parents[1]
arr = np.array(Image.open(ROOT / "assets/icons/logo.png").convert("RGBA"))
mask = logo_mask(arr)
ys, xs = np.where(mask)
PAD = 2
x0, y0 = max(0, int(xs.min()) - PAD), max(0, int(ys.min()) - PAD)
x1, y1 = min(mask.shape[1], int(xs.max()) + 1 + PAD), min(
    mask.shape[0], int(ys.max()) + 1 + PAD
)
crop = mask[y0:y1, x0:x1]
ch, cw = crop.shape[0], crop.shape[1]
svg = (ROOT / "assets/logos/logo.svg").read_text(encoding="utf-8")
d = re.search(r'd="([^"]+)"', svg).group(1)
full = rasterize_path(d, 0, 0, (mask.shape[1], mask.shape[0]))
approx = full[y0:y1, x0:x1]
rgb = np.zeros((ch, cw, 3), dtype=np.uint8)
rgb[crop] = [0, 120, 200]
rgb[approx] = [255, 80, 80]
rgb[crop & approx] = [180, 60, 180]
out = ROOT / "build" / "logo_geom_compare.png"
out.parent.mkdir(exist_ok=True)
Image.fromarray(rgb).save(out)
print(out)
