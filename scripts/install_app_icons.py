#!/usr/bin/env python3
"""Install 1024px brand icons into iOS AppIcon sets and Android mipmaps."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path("/Users/emila/.cursor/projects/Users-emila-TypeScriptProject-turizmtakvim/assets")
BRAND = ROOT / "store/branding"
BRAND.mkdir(parents=True, exist_ok=True)

IOS_SIZES = {
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

ANDROID = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

CONTENTS = (ROOT / "customer/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json").read_text()


def rgb(im: Image.Image) -> Image.Image:
    if im.mode in ("RGBA", "LA"):
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im.convert("RGBA"), mask=im.convert("RGBA").split()[-1])
        return bg
    return im.convert("RGB")


def recolor_teal_to_magenta(im: Image.Image) -> Image.Image:
    """Shift teal management icon to kuafor magenta."""
    src = im.convert("RGBA")
    px = src.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if g > r + 20 and g > b:
                px[x, y] = (190, 24, 93, a)
    return rgb(src)


def write_ios(src: Image.Image, dest_dir: Path) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    (dest_dir / "Contents.json").write_text(CONTENTS)
    master = rgb(src).resize((1024, 1024), Image.Resampling.LANCZOS)
    for name, size in IOS_SIZES.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(dest_dir / name, "PNG")


def write_android(src: Image.Image, res_root: Path) -> None:
    master = rgb(src).resize((1024, 1024), Image.Resampling.LANCZOS)
    for folder, size in ANDROID.items():
        out = res_root / folder
        out.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(out / "ic_launcher.png", "PNG")


def load(name: str) -> Image.Image:
    branded = BRAND / name
    if not branded.exists():
        src = ASSETS / name
        if not src.exists():
            raise SystemExit(f"missing icon {name}")
        shutil.copy2(src, branded)
    return Image.open(branded)


def main() -> None:
    villa = load("villa-app-icon-1024.png")
    kuafor = load("kuafor-app-icon-1024.png")
    yonetim = load("yonetim-app-icon-1024.png")
    kuafor_yonetim = recolor_teal_to_magenta(yonetim)
    kuafor_yonetim.save(BRAND / "kuafor-yonetim-app-icon-1024.png")

    write_ios(villa, ROOT / "customer/ios/Runner/Assets.xcassets/AppIcon-villa.appiconset")
    write_ios(kuafor, ROOT / "customer/ios/Runner/Assets.xcassets/AppIcon-kuafor.appiconset")
    write_ios(kuafor, ROOT / "customer/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    write_android(villa, ROOT / "customer/android/app/src/villa/res")
    write_android(kuafor, ROOT / "customer/android/app/src/kuafor/res")
    write_ios(kuafor, ROOT / "kuafor/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    write_ios(kuafor, ROOT / "kuafor/ios/Runner/Assets.xcassets/AppIcon-kuafor.appiconset")
    write_android(kuafor, ROOT / "kuafor/android/app/src/main/res")
    write_ios(villa, ROOT / "villa/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    write_ios(villa, ROOT / "villa/ios/Runner/Assets.xcassets/AppIcon-villa.appiconset")
    write_android(villa, ROOT / "villa/android/app/src/main/res")

    write_ios(yonetim, ROOT / "mobile/ios/Runner/Assets.xcassets/AppIcon-villa.appiconset")
    write_ios(kuafor_yonetim, ROOT / "mobile/ios/Runner/Assets.xcassets/AppIcon-kuafor.appiconset")
    write_ios(yonetim, ROOT / "mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    write_android(yonetim, ROOT / "mobile/android/app/src/villa/res")
    write_android(kuafor_yonetim, ROOT / "mobile/android/app/src/kuafor/res")
    print("icons installed")


if __name__ == "__main__":
    main()
