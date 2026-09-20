#!/usr/bin/env python3
"""Kuaför Randevu store screenshots (App Store + Play Store)."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML_DIR = ROOT / "store/appstore/kuafor/html"
OUT_IPHONE = ROOT / "store/appstore/kuafor/screenshots"
OUT_PLAY = ROOT / "store/play/kuafor/screenshots/1080x1920"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BRAND_ICON = ROOT / "store/branding/kuafor-app-icon-1024.png"

PINK = "#BE185D"
PINK_DARK = "#9D174D"
CREAM = "#F6F3EE"
INK = "#1F2937"
MUTED = "#6B7280"

CSS = f"""
:root {{
  --pink: {PINK};
  --pink-dark: {PINK_DARK};
  --cream: {CREAM};
  --ink: {INK};
  --muted: {MUTED};
}}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{
  width: 1242px; height: 2688px; overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
  color: white;
}}
.stage {{
  width: 1242px; height: 2688px;
  background: linear-gradient(165deg, #831843 0%, {PINK_DARK} 38%, {PINK} 72%, #F9A8D4 100%);
  padding: 96px 72px 0;
  position: relative;
}}
.kicker {{
  font-size: 28px; font-weight: 700; letter-spacing: 3px; text-transform: uppercase;
  opacity: 0.85; margin-bottom: 28px;
}}
.headline {{
  font-size: 88px; font-weight: 800; line-height: 1.05;
  letter-spacing: -2px; white-space: pre-line;
}}
.sub {{
  margin-top: 28px; font-size: 36px; line-height: 1.35; font-weight: 500;
  opacity: 0.92; max-width: 980px;
}}
.phone {{
  position: absolute; left: 171px; top: 780px;
  width: 900px; height: 1840px;
  background: {CREAM}; color: {INK};
  border-radius: 72px 72px 0 0;
  box-shadow: 0 40px 80px rgba(0,0,0,.28);
  overflow: hidden;
  display: flex; flex-direction: column;
}}
.appbar {{ padding: 36px 40px 20px; display: flex; align-items: center; justify-content: space-between; }}
.appbar h1 {{ font-size: 40px; font-weight: 800; }}
.body {{ flex: 1; padding: 8px 36px 24px; }}
.card {{
  background: #fff; border-radius: 28px; padding: 28px 32px; margin-bottom: 20px;
}}
.card h2 {{ font-size: 34px; font-weight: 800; }}
.card p {{ font-size: 26px; color: {MUTED}; margin-top: 8px; }}
.label {{ font-size: 22px; color: {MUTED}; margin-bottom: 8px; font-weight: 600; }}
.field {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 22px;
  padding: 22px 26px; font-size: 30px; margin-bottom: 18px;
}}
.btn {{
  background: {PINK}; color: #fff; border-radius: 24px; text-align: center;
  padding: 28px; font-size: 32px; font-weight: 800; margin-top: 12px;
}}
.btn.ghost {{ background: #fff; color: {PINK}; border: 3px solid {PINK}; }}
.nav {{
  height: 140px; background: #fff; display: flex; border-top: 1px solid #EDE8E1;
}}
.nav .tab {{
  flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
  font-size: 20px; font-weight: 700; color: {MUTED}; gap: 6px;
}}
.nav .tab.on {{ color: {PINK}; }}
.cal {{ display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; text-align: center; }}
.cal .dow {{ font-size: 20px; color: {MUTED}; font-weight: 700; padding: 8px 0; }}
.cal .d {{
  height: 68px; display: flex; align-items: center; justify-content: center;
  font-size: 26px; font-weight: 700; border-radius: 50%; position: relative;
}}
.cal .d.sel {{ background: {PINK}; color: #fff; }}
.cal .d.busy {{ color: #DC2626; text-decoration: line-through; }}
.cal .d.today {{ background: rgba(190,24,93,.18); }}
.cal .d.dot::after {{
  content: ""; width: 10px; height: 10px; background: {PINK}; border-radius: 50%;
  position: absolute; bottom: 6px;
}}
.cal .d.sel.dot::after {{ background: #fff; }}
.chips {{ display: flex; flex-wrap: wrap; gap: 12px; margin-top: 16px; }}
.chip {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 999px;
  padding: 14px 22px; font-size: 26px; font-weight: 700;
}}
.chip.on {{ background: {PINK}; color: #fff; border-color: {PINK}; }}
.badge {{ font-size: 26px; font-weight: 800; }}
.badge.ok {{ color: #059669; }}
.badge.wait {{ color: #D97706; }}
.hint {{ font-size: 24px; color: {MUTED}; margin: 12px 0 8px; }}
.icon {{ font-size: 32px; }}
.seg {{
  display: flex; background: #fff; border-radius: 18px; padding: 6px; margin-bottom: 28px;
  border: 2px solid #E5E7EB;
}}
.seg-item {{
  flex: 1; text-align: center; padding: 16px 8px; border-radius: 12px;
  font-size: 26px; font-weight: 800; color: {MUTED};
}}
.seg-item.on {{ background: {PINK}; color: #fff; }}
"""


def page(kicker: str, headline: str, sub: str, phone: str) -> str:
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head>
<body><div class="stage">
  <div class="kicker">{kicker}</div>
  <div class="headline">{headline}</div>
  <div class="sub">{sub}</div>
  <div class="phone">{phone}</div>
</div></body></html>"""


def status() -> str:
    return ""


def admin_nav(active: str) -> str:
    tabs = [
        ("takvim", "📅", "Takvim"),
        ("talep", "📥", "Talepler"),
        ("sube", "✂", "Şube"),
        ("musteri", "👤", "Müşteri"),
    ]
    cells = []
    for key, icon, label in tabs:
        on = "on" if key == active else ""
        extra = '<span class="badge wait">2</span>' if key == "talep" and active != "talep" else ""
        cells.append(f'<div class="tab {on}"><span class="icon">{icon}</span>{label}{extra}</div>')
    return '<div class="nav">' + "".join(cells) + "</div>"


def customer_nav(active: str) -> str:
    a = "on" if active == "isletme" else ""
    b = "on" if active == "kayit" else ""
    return f"""<div class="nav">
  <div class="tab {a}"><span class="icon">🏪</span>İşletmem</div>
  <div class="tab {b}"><span class="icon">📅</span>Kayıtlarım</div>
</div>"""


SCREENS = [
    (
        "01-giris",
        "KUAFÖR RANDEVU",
        "İşletme ve\nmüşteri",
        "Aynı uygulamada salon yönetimi ve randevu. Girişte İşletme veya Müşteri seçin.",
        f"""
        {status()}
        <div class="body" style="padding-top:36px">
          <div style="font-size:52px;font-weight:800;line-height:1.1;margin-bottom:12px">Kuaför Randevu</div>
          <p class="hint" style="font-size:26px;margin-bottom:24px">Aynı uygulamada işletme yönetimi ve müşteri randevusu. Yalnızca kuaför sektörü.</p>
          <div class="seg">
            <div class="seg-item on">İşletme</div>
            <div class="seg-item">Müşteri</div>
          </div>
          <div class="label">E-posta</div>
          <div class="field">kuafor@takvim.app</div>
          <div class="label">Şifre</div>
          <div class="field">••••••••</div>
          <div class="btn">Giriş yap</div>
          <p class="hint" style="margin-top:20px">Şifremi unuttum</p>
        </div>
        """,
    ),
    (
        "02-takvim",
        "İŞLETME",
        "Takvimde\nrandevular",
        "Salon yöneticisi dolu günleri ve randevuları tek bakışta görür.",
        f"""
        {status()}
        <div class="appbar"><h1>Elif Kuaför</h1></div>
        <div class="body">
          <div class="card">
            <div style="font-size:30px;font-weight:800;margin-bottom:16px">Eylül 2026</div>
            <div class="cal">
              {"".join(f'<div class="dow">{d}</div>' for d in "P S Ç P C C P".split())}
              {"".join(
            f'<div class="d {cls}">{n}</div>'
            for n, cls in [
                ("1", "dot"), ("2", ""), ("3", ""), ("4", "dot"), ("5", "sel dot"),
                ("6", ""), ("7", ""), ("8", "dot"), ("9", ""), ("10", ""),
                ("11", "dot"), ("12", ""), ("13", ""), ("14", ""), ("15", "dot"),
                ("16", ""), ("17", ""), ("18", "dot"), ("19", ""), ("20", ""),
                ("21", ""), ("22", "dot"), ("23", ""), ("24", ""), ("25", ""),
                ("26", ""), ("27", ""), ("28", "dot"), ("29", ""), ("30", ""),
            ]
        )}
            </div>
          </div>
          <div class="card">
            <h2>Ayşe · 13:00</h2>
            <p>Elif · Saç kesimi</p>
          </div>
        </div>
        {admin_nav("takvim")}
        """,
    ),
    (
        "03-talepler",
        "İŞLETME",
        "Talepleri\nonaylayın",
        "Müşteri randevu talebini onaylayın veya reddedin.",
        f"""
        {status()}
        <div class="appbar"><h1>Talepler</h1></div>
        <div class="body">
          <div class="card">
            <div style="display:flex;justify-content:space-between">
              <div><h2>Ayşe Müşteri</h2><p>10 Eyl 13:00 · Elif · Saç kesimi</p></div>
              <div class="badge wait">Bekliyor</div>
            </div>
            <div class="btn" style="margin-top:20px">Onayla</div>
            <div class="btn ghost">Reddet</div>
          </div>
          <div class="card">
            <h2>Canan</h2>
            <p>12 Eyl 15:30 · Can · Fön</p>
            <div class="badge wait" style="margin-top:12px">Bekliyor</div>
          </div>
        </div>
        {admin_nav("talep")}
        """,
    ),
    (
        "04-subeler",
        "İŞLETME",
        "Şube ve\nkoltuk",
        "Şube veya koltuk ekleyin; randevular bu kayıtlara bağlanır.",
        f"""
        {status()}
        <div class="appbar"><h1>Şubeler</h1></div>
        <div class="body">
          <div class="card">
            <h2>Elif</h2>
            <p>Şube / koltuk</p>
          </div>
          <div class="card">
            <h2>Can</h2>
            <p>Şube / koltuk</p>
          </div>
          <div class="btn">Şube ekle</div>
        </div>
        {admin_nav("sube")}
        """,
    ),
    (
        "05-musteriler",
        "İŞLETME",
        "Müşteri\nekleyin",
        "Müşteri hesabını salon yöneticisi oluşturur. Kayıt açık değildir.",
        f"""
        {status()}
        <div class="appbar"><h1>Müşteriler</h1></div>
        <div class="body">
          <div class="card">
            <h2>Ayşe Müşteri</h2>
            <p>musteri@takvim.app</p>
          </div>
          <div class="card">
            <h2>Canan Demir</h2>
            <p>canan@ornek.com</p>
          </div>
          <div class="btn">Müşteri ekle</div>
        </div>
        {admin_nav("musteri")}
        """,
    ),
    (
        "06-isletme",
        "MÜŞTERİ",
        "Sadece sizin\nsalonunuz",
        "Müşteri yalnızca sizi ekleyen kuaförü görür. Villa bu uygulamada yoktur.",
        f"""
        {status()}
        <div class="appbar"><h1>Kuaför Randevu</h1></div>
        <div class="body">
          <div class="card">
            <h2>Elif Kuaför</h2>
            <p>Kuaför</p>
          </div>
          <div class="card">
            <h2>Şube: Elif</h2>
            <p>Randevu için dokunun</p>
          </div>
        </div>
        {customer_nav("isletme")}
        """,
    ),
    (
        "07-saat",
        "MÜŞTERİ",
        "Müsait saati\nseçin",
        "Takvimde müsait gün ve saati seçip randevu talebi gönderin.",
        f"""
        {status()}
        <div class="appbar"><h1>10 Eylül</h1></div>
        <div class="body">
          <div class="card">
            <h2>Saat</h2>
            <div class="chips">
              <div class="chip">10:00</div>
              <div class="chip">11:00</div>
              <div class="chip on">13:00</div>
              <div class="chip">14:00</div>
              <div class="chip">15:00</div>
              <div class="chip">16:00</div>
            </div>
          </div>
          <div class="card">
            <h2>Hizmet</h2>
            <div class="chips">
              <div class="chip on">Kesim</div>
              <div class="chip">Fön</div>
              <div class="chip">Boyama</div>
            </div>
          </div>
          <div class="btn">Randevu talebi gönder</div>
        </div>
        """,
    ),
    (
        "08-kayitlar",
        "MÜŞTERİ",
        "Randevular\ntek listede",
        "Bekleyen, onaylı ve iptal kayıtlarınızı görün.",
        f"""
        {status()}
        <div class="appbar"><h1>Randevularım</h1></div>
        <div class="body">
          <div class="card">
            <div style="display:flex;justify-content:space-between;align-items:flex-start">
              <div><h2>Elif Kuaför</h2><p>10 Eyl 13:00 · Elif · Kesim</p></div>
              <div class="badge wait">Bekliyor</div>
            </div>
          </div>
          <div class="card">
            <div style="display:flex;justify-content:space-between;align-items:flex-start">
              <div><h2>Elif Kuaför</h2><p>18 Eyl 14:30 · Can · Fön</p></div>
              <div class="badge ok">Onaylı</div>
            </div>
          </div>
        </div>
        {customer_nav("kayit")}
        """,
    ),
    (
        "09-duzenle",
        "DÜZENLE",
        "Saati\ndeğiştirin",
        "Tarihi geçmemiş randevuyu işletme veya müşteri düzenleyebilir.",
        f"""
        {status()}
        <div class="appbar"><h1>Randevu detayı</h1></div>
        <div class="body">
          <div class="badge ok" style="margin-bottom:16px">Onaylı</div>
          <div class="label">Tarih</div>
          <div class="field">18 Eylül 2026</div>
          <div class="label">Saat</div>
          <div class="field">14:30 → 15:00</div>
          <div class="label">Şube</div>
          <div class="field">Can</div>
          <div class="btn">Kaydet</div>
        </div>
        """,
    ),
    (
        "10-iptal",
        "İPTAL",
        "Randevuyu\niptal edin",
        "Geçmemiş randevuyu iptal edin. Kayıt silinmez, iptal olarak kalır.",
        f"""
        {status()}
        <div class="appbar"><h1>Randevu detayı</h1></div>
        <div class="body">
          <div class="card">
            <h2>Elif Kuaför</h2>
            <p>18 Eyl 14:30 · Can · Fön</p>
            <div class="badge ok" style="margin-top:12px">Onaylı</div>
          </div>
          <div class="btn ghost">İptal et</div>
          <div class="card" style="margin-top:24px;text-align:center">
            <h2>İptal edilsin mi?</h2>
            <p>Bu randevu iptal edilecek. Silinmez, iptal olarak kalır.</p>
          </div>
        </div>
        """,
    ),
]

PLAY_SCREENS = [name for name, *_ in SCREENS[:8]]


def capture(html_path: Path, png_path: Path, w: int, h: int) -> None:
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--screenshot={png_path}",
            f"--window-size={w},{h}",
            html_path.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def resize(src: Path, dest: Path, w: int, h: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", str(h), str(w), str(src), "--out", str(dest)], check=True, capture_output=True)


def flatten_png(path: Path) -> None:
    from PIL import Image

    image = Image.open(path).convert("RGB")
    image.save(path, "PNG")


def write_feature_graphic() -> None:
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: 1024px; height: 500px; overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif; color: #fff; }}
.g {{
  width: 1024px; height: 500px;
  background: linear-gradient(115deg, #831843 0%, #9D174D 42%, #BE185D 78%, #F9A8D4 100%);
  display: flex; align-items: center; padding: 56px 72px; gap: 40px;
}}
.icon {{ width: 168px; height: 168px; border-radius: 38px; background: #fff; overflow: hidden; flex-shrink: 0;
  box-shadow: 0 18px 40px rgba(0,0,0,.25); }}
.icon img {{ width: 168px; height: 168px; display: block; }}
h1 {{ font-size: 54px; font-weight: 800; letter-spacing: -1px; }}
p {{ margin-top: 14px; font-size: 26px; font-weight: 600; opacity: .94; max-width: 620px; line-height: 1.35; }}
</style></head>
<body><div class="g">
  <div class="icon"><img src="{BRAND_ICON.as_uri()}" alt=""></div>
  <div>
    <h1>Kuaför Randevu</h1>
    <p>Salon yönetimi ve müşteri randevusu. Takvim, talep, düzenleme ve iptal.</p>
  </div>
</div></body></html>"""
    html_path = ROOT / "store/play/kuafor/feature-graphic.html"
    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(html, encoding="utf-8")
    png = ROOT / "store/play/kuafor/feature-graphic.png"
    capture(html_path, png, 1024, 500)
    flatten_png(png)
    print(f"ok feature {png}")


def copy_icons() -> None:
    ios_icon = ROOT / "store/appstore/kuafor/icon-1024.png"
    play_icon = ROOT / "store/play/kuafor/icon-512.png"
    shutil.copy2(BRAND_ICON, ios_icon)
    play_icon.parent.mkdir(parents=True, exist_ok=True)
    resize(BRAND_ICON, play_icon, 512, 512)
    print(f"ok icon {ios_icon}")
    print(f"ok icon {play_icon}")


def main() -> None:
    if not Path(CHROME).exists():
        raise SystemExit("Google Chrome bulunamadı.")
    sizes = {
        "1242x2688": (1242, 2688),
        "1284x2778": (1284, 2778),
        "1320x2868": (1320, 2868),
        "1290x2796": (1290, 2796),
    }
    folders = [HTML_DIR, OUT_PLAY] + [OUT_IPHONE / name for name in sizes]
    for folder in folders:
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True)

    for name, kicker, headline, sub, phone in SCREENS:
        html = page(kicker, headline, sub, phone)
        html_path = HTML_DIR / f"{name}.html"
        html_path.write_text(html, encoding="utf-8")
        src = OUT_IPHONE / "1242x2688" / f"{name}.png"
        capture(html_path, src, 1242, 2688)
        flatten_png(src)
        for label, (w, h) in sizes.items():
            if label == "1242x2688":
                continue
            resize(src, OUT_IPHONE / label / f"{name}.png", w, h)
        if name in PLAY_SCREENS:
            dest = OUT_PLAY / f"{name}.png"
            resize(src, dest, 1080, 1920)
            flatten_png(dest)
        print(f"ok {name}")

    write_feature_graphic()
    copy_icons()
    print(f"Hazır iPhone: {OUT_IPHONE}")
    print(f"Hazır Play: {OUT_PLAY}")


if __name__ == "__main__":
    main()
