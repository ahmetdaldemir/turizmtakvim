#!/usr/bin/env python3
"""Yönetim App Store screenshots at Apple iPhone sizes."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_65 = ROOT / "store/appstore/yonetim/screenshots/1242x2688"
OUT_67 = ROOT / "store/appstore/yonetim/screenshots/1284x2778"
HTML_DIR = ROOT / "store/appstore/yonetim/html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

TEAL = "#0F766E"
TEAL_DARK = "#115E59"
CREAM = "#F7F5F2"
INK = "#111827"
MUTED = "#6B7280"

CSS = f"""
:root {{ --teal:{TEAL}; --cream:{CREAM}; --ink:{INK}; --muted:{MUTED}; }}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{
  width: 1242px; height: 2688px; overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
  color: white;
}}
.stage {{
  width: 1242px; height: 2688px;
  background: linear-gradient(165deg, #042F2E 0%, {TEAL_DARK} 40%, {TEAL} 72%, #5EEAD4 100%);
  padding: 96px 72px 0; position: relative;
}}
.kicker {{
  font-size: 28px; font-weight: 700; letter-spacing: 3px; text-transform: uppercase;
  opacity: .85; margin-bottom: 28px;
}}
.headline {{
  font-size: 88px; font-weight: 800; line-height: 1.05;
  letter-spacing: -2px; white-space: pre-line;
}}
.sub {{
  margin-top: 28px; font-size: 36px; line-height: 1.35; font-weight: 500;
  opacity: .92; max-width: 980px;
}}
.phone {{
  position: absolute; left: 171px; top: 780px;
  width: 900px; height: 1840px;
  background: {CREAM}; color: {INK};
  border-radius: 72px 72px 0 0;
  box-shadow: 0 40px 80px rgba(0,0,0,.28);
  overflow: hidden; display: flex; flex-direction: column;
}}
.status {{
  height: 92px; display: flex; align-items: center; justify-content: space-between;
  padding: 28px 48px 0; font-size: 28px; font-weight: 700;
}}
.appbar {{ padding: 36px 40px 20px; display: flex; align-items: center; justify-content: space-between; }}
.appbar h1 {{ font-size: 40px; font-weight: 800; }}
.body {{ flex: 1; padding: 8px 36px 24px; }}
.card {{ background: #fff; border-radius: 28px; padding: 28px 32px; margin-bottom: 20px; }}
.card h2 {{ font-size: 34px; font-weight: 800; }}
.card p {{ font-size: 26px; color: {MUTED}; margin-top: 8px; }}
.label {{ font-size: 22px; color: {MUTED}; margin-bottom: 8px; font-weight: 600; }}
.field {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 22px;
  padding: 22px 26px; font-size: 30px; margin-bottom: 18px;
}}
.btn {{
  background: {TEAL}; color: #fff; border-radius: 24px; text-align: center;
  padding: 28px; font-size: 32px; font-weight: 800; margin-top: 12px;
}}
.btn.ghost {{ background: #fff; color: {TEAL}; border: 3px solid {TEAL}; }}
.btn.warn {{ background: #fff; color: #B45309; border: 3px solid #F59E0B; }}
.nav {{
  height: 140px; background: #fff; display: flex; border-top: 1px solid #EDE8E1;
}}
.nav .tab {{
  flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
  font-size: 20px; font-weight: 700; color: {MUTED}; gap: 6px;
}}
.nav .tab.on {{ color: {TEAL}; }}
.cal {{ display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; text-align: center; }}
.cal .dow {{ font-size: 20px; color: {MUTED}; font-weight: 700; padding: 8px 0; }}
.cal .d {{
  height: 68px; display: flex; align-items: center; justify-content: center;
  font-size: 26px; font-weight: 700; border-radius: 50%; position: relative;
}}
.cal .d.sel {{ background: {TEAL}; color: #fff; }}
.cal .d.dot::after {{
  content: ""; width: 10px; height: 10px; background: {TEAL}; border-radius: 50%;
  position: absolute; bottom: 6px;
}}
.cal .d.sel.dot::after {{ background: #fff; }}
.chips {{ display: flex; flex-wrap: wrap; gap: 12px; margin-top: 16px; }}
.chip {{
  background: #fff; border: 2px solid #E5E7EB; border-radius: 999px;
  padding: 14px 22px; font-size: 26px; font-weight: 700;
}}
.chip.on {{ background: {TEAL}; color: #fff; border-color: {TEAL}; }}
.badge {{ font-size: 26px; font-weight: 800; }}
.badge.ok {{ color: #059669; }}
.badge.wait {{ color: #D97706; }}
.hint {{ font-size: 24px; color: {MUTED}; margin: 12px 0 8px; }}
.icon {{ font-size: 32px; }}
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


def nav(active: str) -> str:
    tabs = [
        ("takvim", "📅", "Takvim"),
        ("talep", "📥", "Talepler"),
        ("villa", "🏠", "Villa"),
        ("musteri", "👤", "Müşteri"),
    ]
    cells = []
    for key, icon, label in tabs:
        on = "on" if key == active else ""
        extra = '<span class="badge wait">2</span>' if key == "talep" and active != "talep" else ""
        cells.append(f'<div class="tab {on}"><span class="icon">{icon}</span>{label}{extra}</div>')
    return '<div class="nav">' + "".join(cells) + "</div>"


SCREENS = [
    (
        "01-giris",
        "YÖNETİM",
        "Takvim ve\ntalepler",
        "Villa ve kuaför işletmenizi tek uygulamadan yönetin.",
        f"""
        {status()}
        <div class="body" style="padding-top:48px">
          <div style="font-size:56px;font-weight:800;margin-bottom:8px">Yönetim</div>
          <p class="hint" style="font-size:28px;margin-bottom:36px">Takvim ve talepler</p>
          <div class="label">E-posta</div>
          <div class="field">yonetici@ornek.com</div>
          <div class="label">Şifre</div>
          <div class="field">••••••••</div>
          <div class="btn">Giriş yap</div>
          <p class="hint" style="margin-top:24px">Şifremi unuttum</p>
        </div>
        """,
    ),
    (
        "02-takvim",
        "TAKVİM",
        "Dolu günler\ntek bakışta",
        "Rezervasyon ve randevular takvimde işaretlenir.",
        f"""
        {status()}
        <div class="appbar"><h1>Villa Ege</h1><span class="icon">🔍</span></div>
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
            <h2>Villa Deniz</h2>
            <p>5–12 Eyl · Onaylı</p>
          </div>
        </div>
        {nav("takvim")}
        """,
    ),
    (
        "03-gun",
        "GÜN",
        "Günün kayıtları",
        "Seçilen gündeki rezervasyonları görün, düzenleyin veya iptal edin.",
        f"""
        {status()}
        <div class="appbar"><h1>5 Eylül</h1></div>
        <div class="body">
          <div class="card">
            <div style="display:flex;justify-content:space-between">
              <div><h2>Villa Deniz</h2><p>Ayşe Yılmaz · 5–12 Eyl</p></div>
              <div class="badge ok">Onaylı</div>
            </div>
          </div>
          <div class="card">
            <div style="display:flex;justify-content:space-between">
              <div><h2>Villa Bahçe</h2><p>Can Demir · 5–8 Eyl</p></div>
              <div class="badge wait">Bekliyor</div>
            </div>
          </div>
          <div class="btn">Rezervasyon ekle</div>
        </div>
        {nav("takvim")}
        """,
    ),
    (
        "04-talepler",
        "TALEPLER",
        "Onaylayın\nveya reddedin",
        "Müşteri talepleri bildirilir. Onaylayınca takvime düşer.",
        f"""
        {status()}
        <div class="appbar"><h1>Talepler</h1></div>
        <div class="body">
          <div class="card">
            <h2>Ayşe Yılmaz</h2>
            <p>Villa Deniz · 12–19 Eyl</p>
            <div class="badge wait" style="margin:12px 0">Bekliyor</div>
            <div style="display:flex;gap:12px">
              <div class="btn" style="flex:1;padding:18px;font-size:26px">Onayla</div>
              <div class="btn ghost" style="flex:1;padding:18px;font-size:26px;margin-top:12px">Reddet</div>
            </div>
          </div>
          <div class="card">
            <h2>Can Demir</h2>
            <p>Villa Bahçe · 20–25 Eyl</p>
            <div class="badge wait" style="margin-top:12px">Bekliyor</div>
          </div>
        </div>
        {nav("talep")}
        """,
    ),
    (
        "05-villa",
        "VİLLA / ŞUBE",
        "Kaynaklarınızı\ntanın",
        "Villa, şube veya koltuk ekleyin. Takvim kaynağa göre dolar.",
        f"""
        {status()}
        <div class="appbar"><h1>Villa</h1></div>
        <div class="body">
          <div class="card"><h2>Villa Deniz</h2><p>Kaş · 8 kişi</p></div>
          <div class="card"><h2>Villa Bahçe</h2><p>Kalkan · 6 kişi</p></div>
          <div class="card"><h2>Villa Tepe</h2><p>Fethiye · 10 kişi</p></div>
          <div class="btn">Villa ekle</div>
        </div>
        {nav("villa")}
        """,
    ),
    (
        "06-musteri",
        "MÜŞTERİ",
        "Müşteriyi siz\nekleriniz",
        "Hesabı yönetici oluşturur. Müşteri kendi uygulamasından talep gönderir.",
        f"""
        {status()}
        <div class="appbar"><h1>Müşteri</h1></div>
        <div class="body">
          <div class="card"><h2>Ayşe Yılmaz</h2><p>ayse@ornek.com</p></div>
          <div class="card"><h2>Can Demir</h2><p>can@ornek.com</p></div>
          <div class="card"><h2>Elif Kaya</h2><p>elif@ornek.com</p></div>
          <div class="btn">Müşteri ekle</div>
        </div>
        {nav("musteri")}
        """,
    ),
    (
        "07-duzenle",
        "DÜZENLE",
        "Kaydı güncelleyin",
        "Tarihi, villayı ve durumu değiştirin. Çakışma kontrol edilir.",
        f"""
        {status()}
        <div class="appbar"><h1>Rezervasyon</h1></div>
        <div class="body">
          <div class="label">Villa</div>
          <div class="field">Villa Deniz</div>
          <div class="label">Müşteri</div>
          <div class="field">Ayşe Yılmaz</div>
          <div class="label">Giriş / çıkış</div>
          <div class="field">5 Eyl – 12 Eyl</div>
          <div class="chips">
            <div class="chip on">Onaylı</div>
            <div class="chip">Bekliyor</div>
            <div class="chip">İptal</div>
          </div>
          <div class="btn">Kaydet</div>
        </div>
        """,
    ),
    (
        "08-iptal",
        "İPTAL",
        "Silmeden\niptal edin",
        "Kayıt silinmez; iptal olarak kalır. Takvim işareti kalkar.",
        f"""
        {status()}
        <div class="appbar"><h1>Rezervasyon</h1></div>
        <div class="body">
          <div class="card">
            <h2>Villa Deniz</h2>
            <p>Ayşe Yılmaz · 5–12 Eyl</p>
            <div class="badge ok" style="margin-top:12px">Onaylı</div>
          </div>
          <div class="btn warn">İptal et</div>
          <div class="card" style="margin-top:24px;text-align:center">
            <h2>İptal edilsin mi?</h2>
            <p>Kayıt silinmez, iptal olarak görünür.</p>
          </div>
        </div>
        """,
    ),
    (
        "09-sektor",
        "SEKTÖR",
        "Villa veya\nkuaför",
        "Aynı yönetim uygulaması; giriş yaptığınız sektörün takvimi açılır.",
        f"""
        {status()}
        <div class="body" style="padding-top:36px">
          <div class="card">
            <h2>Villa</h2>
            <p>Konaklama. Giriş–çıkış tarihi, villa takvimi.</p>
          </div>
          <div class="card">
            <h2>Kuaför</h2>
            <p>Randevu. Tek gün, saat ve şube / koltuk.</p>
          </div>
          <div class="card">
            <h2>Müşteri ayrı</h2>
            <p>Villa müşterisi Kuaför Randevu’yu görmez.</p>
          </div>
        </div>
        {nav("takvim")}
        """,
    ),
    (
        "10-filtre",
        "SÜZ",
        "Tarih aralığı\nile bakın",
        "Takvimde dönem seçin; o aralıktaki tüm kayıtlar listelenir.",
        f"""
        {status()}
        <div class="appbar"><h1>Filtre</h1></div>
        <div class="body">
          <div class="label">Başlangıç</div>
          <div class="field">1 Eylül 2026</div>
          <div class="label">Bitiş</div>
          <div class="field">30 Eylül 2026</div>
          <div class="btn">Uygula</div>
          <div class="card" style="margin-top:20px">
            <h2>8 kayıt</h2>
            <p>Eylül ayı · Villa Ege</p>
          </div>
        </div>
        {nav("takvim")}
        """,
    ),
]


def capture(html_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--screenshot={png_path}",
            "--window-size=1242,2688",
            html_path.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def resize(src: Path, dest: Path, w: int, h: int) -> None:
    subprocess.run(["sips", "-z", str(h), str(w), str(src), "--out", str(dest)], check=True, capture_output=True)


def main() -> None:
    if not Path(CHROME).exists():
        raise SystemExit("Google Chrome bulunamadı.")
    for folder in (OUT_65, OUT_67, HTML_DIR):
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True)

    for name, kicker, headline, sub, phone in SCREENS:
        html_path = HTML_DIR / f"{name}.html"
        html_path.write_text(page(kicker, headline, sub, phone), encoding="utf-8")
        png_65 = OUT_65 / f"{name}.png"
        capture(html_path, png_65)
        resize(png_65, OUT_67 / f"{name}.png", 1284, 2778)
        print(f"ok {name}")

    print(f"Hazır: {OUT_65}")
    print(f"Hazır: {OUT_67}")


if __name__ == "__main__":
    main()
