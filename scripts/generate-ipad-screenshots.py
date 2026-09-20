#!/usr/bin/env python3
"""iPad App Store screenshots: 2064×2752 and 2048×2732."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 2064, 2752
W12, H12 = 2048, 2732


def load(name: str):
    path = SCRIPTS / name
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def css(accent: str, dark: str, cream: str, ink: str, muted: str, gradient: str) -> str:
    return f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{
  width: {W}px; height: {H}px; overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
  color: #fff;
}}
.stage {{
  width: {W}px; height: {H}px;
  background: {gradient};
  padding: 110px 96px 0;
  position: relative;
}}
.kicker {{
  font-size: 32px; font-weight: 700; letter-spacing: 4px; text-transform: uppercase;
  opacity: .85; margin-bottom: 24px;
}}
.headline {{
  font-size: 104px; font-weight: 800; line-height: 1.05;
  letter-spacing: -2px; white-space: pre-line;
}}
.sub {{
  margin-top: 28px; font-size: 40px; line-height: 1.35; font-weight: 500;
  opacity: .92; max-width: 1500px;
}}
.phone {{
  position: absolute; left: 132px; top: 820px;
  width: 1800px; height: 1932px;
  background: {cream}; color: {ink};
  border-radius: 44px 44px 0 0;
  box-shadow: 0 40px 90px rgba(0,0,0,.28);
  overflow: hidden; display: flex; flex-direction: column;
}}
.appbar {{ padding: 48px 48px 24px; display: flex; align-items: center; justify-content: space-between; }}
.appbar h1 {{ font-size: 48px; font-weight: 800; }}
.body {{ flex: 1; padding: 8px 48px 24px; }}
.card {{ background: #fff; border-radius: 28px; padding: 32px 36px; margin-bottom: 22px; }}
.card h2 {{ font-size: 40px; font-weight: 800; }}
.card p {{ font-size: 30px; color: {muted}; margin-top: 8px; }}
.label {{ font-size: 26px; color: {muted}; margin-bottom: 10px; font-weight: 600; }}
.field {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 22px;
  padding: 24px 28px; font-size: 34px; margin-bottom: 18px;
}}
.btn {{
  background: {accent}; color: #fff; border-radius: 24px; text-align: center;
  padding: 28px; font-size: 34px; font-weight: 800; margin-top: 12px;
}}
.btn.ghost {{ background: #fff; color: {accent}; border: 3px solid {accent}; }}
.btn.warn {{ background: #fff; color: #B45309; border: 3px solid #F59E0B; }}
.nav {{
  height: 150px; background: #fff; display: flex; border-top: 1px solid #EDE8E1;
}}
.nav .tab {{
  flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
  font-size: 24px; font-weight: 700; color: {muted}; gap: 8px;
}}
.nav .tab.on {{ color: {accent}; }}
.cal {{ display: grid; grid-template-columns: repeat(7, 1fr); gap: 10px; text-align: center; }}
.cal .dow {{ font-size: 24px; color: {muted}; font-weight: 700; padding: 10px 0; }}
.cal .d {{
  height: 86px; display: flex; align-items: center; justify-content: center;
  font-size: 32px; font-weight: 700; border-radius: 50%; position: relative;
}}
.cal .d.sel {{ background: {accent}; color: #fff; }}
.cal .d.busy {{ color: #DC2626; text-decoration: line-through; }}
.cal .d.today {{ background: color-mix(in srgb, {accent} 18%, white); }}
.cal .d.dot::after {{
  content: ""; width: 12px; height: 12px; background: {accent}; border-radius: 50%;
  position: absolute; bottom: 8px;
}}
.cal .d.sel.dot::after {{ background: #fff; }}
.chips {{ display: flex; flex-wrap: wrap; gap: 14px; margin-top: 16px; }}
.chip {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 999px;
  padding: 16px 26px; font-size: 30px; font-weight: 700;
}}
.chip.on {{ background: {accent}; color: #fff; border-color: {accent}; }}
.badge {{ font-size: 30px; font-weight: 800; }}
.badge.ok {{ color: #059669; }}
.badge.wait {{ color: #D97706; }}
.hint {{ font-size: 28px; color: {muted}; margin: 12px 0 8px; }}
.icon {{ font-size: 36px; }}
.seg {{
  display: flex; background: #fff; border-radius: 18px; padding: 8px; margin-bottom: 28px;
  border: 2px solid #E5E7EB;
}}
.seg-item {{
  flex: 1; text-align: center; padding: 18px 8px; border-radius: 12px;
  font-size: 30px; font-weight: 800; color: {muted};
}}
.seg-item.on {{ background: {accent}; color: #fff; }}
"""


def page(style: str, kicker: str, headline: str, sub: str, phone: str) -> str:
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{style}</style></head>
<body><div class="stage">
  <div class="kicker">{kicker}</div>
  <div class="headline">{headline}</div>
  <div class="sub">{sub}</div>
  <div class="phone">{phone}</div>
</div></body></html>"""


def capture(html_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--screenshot={png_path}",
            f"--window-size={W},{H}",
            html_path.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def resize(src: Path, dest: Path, w: int, h: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(h), str(w), str(src), "--out", str(dest)], check=True, capture_output=True)


def render(app: str, screens, style: str) -> None:
    html_dir = ROOT / f"store/appstore/{app}/html-ipad"
    out_13 = ROOT / f"store/appstore/{app}/screenshots/2064x2752"
    out_12 = ROOT / f"store/appstore/{app}/screenshots/2048x2732"
    for folder in (html_dir, out_13, out_12):
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True)

    for name, kicker, headline, sub, phone in screens:
        html_path = html_dir / f"{name}.html"
        html_path.write_text(page(style, kicker, headline, sub, phone), encoding="utf-8")
        png = out_13 / f"{name}.png"
        capture(html_path, png)
        resize(png, out_12 / f"{name}.png", W12, H12)
        print(f"ok {app} {name}")
    print(f"Hazır: {out_13}")
    print(f"Hazır: {out_12}")


def main() -> None:
    if not Path(CHROME).exists():
        raise SystemExit("Google Chrome bulunamadı.")
    sys.dont_write_bytecode = True
    wanted = sys.argv[1:] or ["kuafor", "villa", "yonetim"]
    kuafor_css = css(
        "#BE185D",
        "#9D174D",
        "#F6F3EE",
        "#1F2937",
        "#6B7280",
        "linear-gradient(165deg, #831843 0%, #9D174D 38%, #BE185D 72%, #F9A8D4 100%)",
    )
    villa_css = css(
        "#0F766E",
        "#115E59",
        "#F7F5F2",
        "#111827",
        "#6B7280",
        "linear-gradient(165deg, #042F2E 0%, #115E59 40%, #0F766E 72%, #5EEAD4 100%)",
    )
    if "kuafor" in wanted:
        render("kuafor", load("generate-kuafor-screenshots.py").SCREENS, kuafor_css)
    if "villa" in wanted:
        render("villa", load("generate-villa-screenshots.py").SCREENS, villa_css)
    if "yonetim" in wanted:
        render("yonetim", load("generate-yonetim-screenshots.py").SCREENS, villa_css)


if __name__ == "__main__":
    main()
