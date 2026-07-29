"""Regenerate raster brand icons from assets/logos SVGs."""
from __future__ import annotations

import argparse
import shutil
import subprocess
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOGOS = ROOT / "assets" / "logos"
BRAND = ROOT / "assets" / "brand"

# Canvas sizes for launcher / favicon generation.
MASTER_SIZE = 1024
TRANSPARENT = (0, 0, 0, 0)

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

WEB_ICON_SIZES = {
    "favicon.png": 32,
    "icons/Icon-192.png": 192,
    "icons/Icon-512.png": 512,
    "icons/Icon-maskable-192.png": 192,
    "icons/Icon-maskable-512.png": 512,
}

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_ICONS = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}


def _magick_exe() -> str:
    for candidate in ("magick", "convert"):
        if shutil.which(candidate):
            return candidate
    raise SystemExit(
        "ImageMagick (magick) is required to render SVGs. "
        "Install from https://imagemagick.org or add it to PATH."
    )


def _render_svg(svg_path: Path, size: int, bg: str | None = None) -> Image.Image:
    magick = _magick_exe()
    background = bg if bg else "none"
    cmd = [
        magick,
        "-background",
        background,
        "-density",
        "384",
        str(svg_path),
        "-resize",
        f"{size}x{size}",
        "png:-",
    ]
    result = subprocess.run(cmd, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            f"ImageMagick failed for {svg_path}:\n{result.stderr.decode(errors='replace')}"
        )

    img = Image.open(BytesIO(result.stdout)).convert("RGBA")
    if bg and bg != "none":
        canvas = Image.new("RGBA", (size, size), bg)
        canvas.alpha_composite(img)
        return canvas
    return img


def _fit_logo_on_square(
    img: Image.Image,
    canvas_size: int,
    bg: tuple[int, int, int, int] = TRANSPARENT,
    padding: float = 0.12,
) -> Image.Image:
    canvas = Image.new("RGBA", (canvas_size, canvas_size), bg)
    inner = int(canvas_size * (1 - 2 * padding))
    fitted = img.copy()
    fitted.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (canvas_size - fitted.width) // 2
    y = (canvas_size - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def _save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if img.mode == "RGBA":
        img.save(path, format="PNG")
    else:
        img.convert("RGB").save(path, format="PNG")


def _save_ico(images: list[Image.Image], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    base = images[0].convert("RGBA")
    base.save(path, format="ICO", sizes=[(img.width, img.height) for img in images])


def render_primary(primary: str) -> None:
    if primary not in {"teal", "orange"}:
        raise SystemExit("--primary must be teal or orange")

    colored_svg = LOGOS / f"logo_{primary}.svg"
    if not colored_svg.exists():
        raise SystemExit(f"Missing SVG: {colored_svg}")

    out_root = BRAND / "launcher" / primary
    master = _fit_logo_on_square(
        _render_svg(colored_svg, MASTER_SIZE, bg="none"),
        MASTER_SIZE,
    )
    _save_png(master, out_root / "master_1024.png")

    def write_resized(rel: str, px: int) -> None:
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        _save_png(resized, out_root / rel)

    for density, px in ANDROID_SIZES.items():
        write_resized(f"android/{density}/ic_launcher.png", px)

    for name, px in IOS_ICONS.items():
        write_resized(f"ios/{name}", px)

    for name, px in MACOS_ICONS.items():
        write_resized(f"macos/{name}", px)

    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = [master.resize((s, s), Image.Resampling.LANCZOS) for s in ico_sizes]
    _save_ico(ico_images, out_root / "windows" / "app_icon.ico")

    for rel, px in WEB_ICON_SIZES.items():
        write_resized(f"web/{rel}", px)

    # Favicons: brand color for light tabs, white logo for dark tabs (no canvas bg).
    fav_dir = BRAND / "favicon"
    light_logo = _fit_logo_on_square(
        _render_svg(colored_svg, 64, bg="none"),
        64,
    )
    dark_logo = _fit_logo_on_square(
        _render_svg(LOGOS / "logo_white.svg", 64, bg="none"),
        64,
    )
    _save_png(light_logo, fav_dir / f"{primary}_light.png")
    _save_png(dark_logo, fav_dir / f"{primary}_dark.png")

    web_fav = ROOT / "web" / "favicons"
    web_fav.mkdir(parents=True, exist_ok=True)
    shutil.copy2(fav_dir / f"{primary}_light.png", web_fav / f"{primary}_light.png")
    shutil.copy2(fav_dir / f"{primary}_dark.png", web_fav / f"{primary}_dark.png")

    print(f"Rendered {primary} brand icons under {out_root.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--primary",
        choices=("teal", "orange", "all"),
        default="all",
        help="Which primary palette to render (default: all)",
    )
    args = parser.parse_args()
    targets = ["teal", "orange"] if args.primary == "all" else [args.primary]
    for primary in targets:
        render_primary(primary)


if __name__ == "__main__":
    main()
