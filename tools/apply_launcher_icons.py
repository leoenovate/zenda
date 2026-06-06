"""Copy pre-rendered brand launcher assets into platform trees."""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand" / "launcher"

ANDROID_DENSITIES = (
    "mipmap-mdpi",
    "mipmap-hdpi",
    "mipmap-xhdpi",
    "mipmap-xxhdpi",
    "mipmap-xxxhdpi",
)

IOS_ICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_ICON_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
WEB_DIR = ROOT / "web"
WEB_FAVICONS = ROOT / "web" / "favicons"


def _copy_tree(src: Path, dst: Path, pattern: str = "*") -> int:
    count = 0
    if not src.exists():
        raise FileNotFoundError(f"Missing source: {src}")
    dst.mkdir(parents=True, exist_ok=True)
    for item in sorted(src.glob(pattern)):
        if item.is_file():
            shutil.copy2(item, dst / item.name)
            count += 1
    return count


def apply(primary: str) -> None:
    if primary not in {"teal", "orange"}:
        raise SystemExit("--primary must be teal or orange")

    src_root = BRAND / primary
    if not src_root.exists():
        raise SystemExit(f"Brand assets not found: {src_root}")

    # Android
    for density in ANDROID_DENSITIES:
        src = src_root / "android" / density / "ic_launcher.png"
        dst = ROOT / "android" / "app" / "src" / "main" / "res" / density / "ic_launcher.png"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"android: {dst.relative_to(ROOT)}")

    # iOS
    ios_src = src_root / "ios"
    _copy_tree(ios_src, IOS_ICON_DIR, "Icon-App-*.png")
    print(f"ios: {IOS_ICON_DIR.relative_to(ROOT)} ({len(list(ios_src.glob('Icon-App-*.png')))} files)")

    # macOS
    macos_src = src_root / "macos"
    _copy_tree(macos_src, MACOS_ICON_DIR, "app_icon_*.png")
    print(f"macos: {MACOS_ICON_DIR.relative_to(ROOT)} ({len(list(macos_src.glob('app_icon_*.png')))} files)")

    # Windows
    shutil.copy2(src_root / "windows" / "app_icon.ico", WINDOWS_ICON)
    print(f"windows: {WINDOWS_ICON.relative_to(ROOT)}")

    # Web static launcher + PWA icons
    web_src = src_root / "web"
    shutil.copy2(web_src / "favicon.png", WEB_DIR / "favicon.png")
    icons_dst = WEB_DIR / "icons"
    icons_dst.mkdir(parents=True, exist_ok=True)
    for icon in web_src.glob("icons/*.png"):
        shutil.copy2(icon, icons_dst / icon.name)
    print(f"web: favicon.png + {len(list(web_src.glob('icons/*.png')))} icons")

    # Runtime favicons (both primaries × light/dark) from brand/favicon
    fav_src = ROOT / "assets" / "brand" / "favicon"
    WEB_FAVICONS.mkdir(parents=True, exist_ok=True)
    for hue in ("teal", "orange"):
        for mode in ("light", "dark"):
            name = f"{hue}_{mode}.png"
            if (fav_src / name).exists():
                shutil.copy2(fav_src / name, WEB_FAVICONS / name)
    print("web: favicons/{teal,orange}_{light,dark}.png")

    print(f"\nApplied {primary} launcher icons.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--primary",
        choices=("teal", "orange"),
        default="orange",
        help="Brand primary hue to apply (default: orange)",
    )
    args = parser.parse_args()
    apply(args.primary)


if __name__ == "__main__":
    main()
