#!/usr/bin/env python3
"""Copy admin/customer sources into packages/musait and clone two app projects."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "packages/musait/lib"

SKIP = {".dart_tool", "build", "Pods", ".symlinks", "ephemeral", ".gradle"}


def copy_tree(src: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        src,
        dest,
        dirs_exist_ok=True,
        ignore=shutil.ignore_patterns(
            ".dart_tool",
            "build",
            "Pods",
            ".symlinks",
            "ephemeral",
            ".gradle",
            "*.iml",
            ".idea",
            ".flutter-plugins",
            ".flutter-plugins-dependencies",
            "xcuserdata",
            "*.xcuserstate",
        ),
    )


def rewrite(path: Path, mapping: dict[str, str]) -> None:
    text = path.read_text()
    for old, new in mapping.items():
        text = text.replace(old, new)
    path.write_text(text)


def copy_admin() -> None:
    admin = PKG / "admin"
    if admin.exists():
        shutil.rmtree(admin)
    admin.mkdir()
    shutil.copytree(ROOT / "mobile/lib/models", admin / "models")
    shutil.copytree(ROOT / "mobile/lib/screens", admin / "screens")
    shutil.copytree(ROOT / "mobile/lib/widgets", admin / "widgets")
    for dart in admin.rglob("*.dart"):
        rewrite(
            dart,
            {
                "import '../config.dart';": "import 'package:musait/config.dart';",
                "import '../theme.dart';": "import 'package:musait/theme.dart';",
                "import '../../config.dart';": "import 'package:musait/config.dart';",
                "import '../../theme.dart';": "import 'package:musait/theme.dart';",
            },
        )


def copy_customer() -> None:
    customer = PKG / "customer"
    if customer.exists():
        shutil.rmtree(customer)
    customer.mkdir()
    for name in ("api.dart", "models.dart", "session.dart"):
        shutil.copy2(ROOT / "customer/lib" / name, customer / name)
    shutil.copytree(ROOT / "customer/lib/screens", customer / "screens")
    (customer / "screens/login_screen.dart").unlink(missing_ok=True)
    for dart in customer.rglob("*.dart"):
        rewrite(
            dart,
            {
                "import '../config.dart';": "import 'package:musait/config.dart';",
                "import '../theme.dart';": "import 'package:musait/theme.dart';",
                "import 'config.dart';": "import 'package:musait/config.dart';",
                "import 'theme.dart';": "import 'package:musait/theme.dart';",
            },
        )


def rsync_app(dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    copy_tree(ROOT / "customer", dest)
    for extra in ["lib", "test"]:
        p = dest / extra
        if p.exists():
            shutil.rmtree(p)
    (dest / "lib").mkdir()


def write_app_main(dest: Path, sector: str, title: str) -> None:
    (dest / "lib/main.dart").write_text(
        "import 'package:musait/musait.dart';\n\n"
        f"Future<void> main() => MusaitApp.start(sector: '{sector}');\n"
    )
    pub = (dest / "pubspec.yaml").read_text()
    pub = re.sub(r"^name: .*$", f"name: {dest.name}_app", pub, count=1, flags=re.M)
    pub = re.sub(r"^description: .*$", f"description: {title}", pub, count=1, flags=re.M)
    if "musait:" not in pub:
        pub = pub.replace(
            "  table_calendar: ^3.2.0\n",
            "  table_calendar: ^3.2.0\n  musait:\n    path: ../packages/musait\n",
        )
    (dest / "pubspec.yaml").write_text(pub)


def simplify_android(dest: Path, app_id: str, app_name: str, color: str) -> None:
    gradle = dest / "android/app/build.gradle.kts"
    text = gradle.read_text()
    text = re.sub(r"\n    flavorDimensions[\s\S]*?    \}\n\n    signingConfigs", "\n    signingConfigs", text)
    text = re.sub(
        r'applicationId = "com.musaitvillam.villa"',
        f'applicationId = "{app_id}"',
        text,
        count=1,
    )
    gradle.write_text(text)
    namespace = dest / "android/app/build.gradle.kts"
    g = namespace.read_text().replace('namespace = "com.musaitvillam.musteri"', f'namespace = "{app_id}"')
    namespace.write_text(g)
    old_kt = dest / "android/app/src/main/kotlin/com/musaitvillam/musteri"
    new_kt = dest / f"android/app/src/main/kotlin/{app_id.replace('.', '/')}"
    new_kt.mkdir(parents=True, exist_ok=True)
    (new_kt / "MainActivity.kt").write_text(
        f"package {app_id}\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n"
    )
    if old_kt.exists() and old_kt.resolve() != new_kt.resolve():
        shutil.rmtree(old_kt)
    flavor = "kuafor" if app_id.endswith(".kuafor") else "villa"
    src = dest / f"android/app/src/{flavor}/res"
    dst = dest / "android/app/src/main/res"
    if src.exists():
        for mip in src.glob("mipmap-*"):
            target = dst / mip.name
            target.mkdir(parents=True, exist_ok=True)
            for png in mip.glob("*.png"):
                shutil.copy2(png, target / png.name)
    values = dest / "android/app/src/main/res/values/strings.xml"
    values.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <string name="app_name">{app_name}</string>\n'
        "</resources>\n"
    )
    colors = dest / "android/app/src/main/res/values/colors.xml"
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="launch_color">{color}</color>\n'
        "</resources>\n"
    )
    for flavor in ("villa", "kuafor"):
        p = dest / f"android/app/src/{flavor}"
        if p.exists():
            shutil.rmtree(p)


def strip_flavor_pbx(pbx: Path) -> None:
    text = pbx.read_text()
    text = re.sub(
        r"^\t\t[A-F0-9]{24} /\* Pods-Runner[^*]*-(?:villa|kuafor)\.xcconfig \*/ = \{isa = PBXFileReference;[^\n]*\n",
        "",
        text,
        flags=re.M,
    )
    text = re.sub(
        r"^\t\t\t\t[A-F0-9]{24} /\* Pods-Runner[^*]*-(?:villa|kuafor)\.xcconfig \*/,\n",
        "",
        text,
        flags=re.M,
    )
    text = re.sub(
        r"^\t\t\t\t[A-F0-9]{24} /\* (?:Debug|Profile|Release)-(?:villa|kuafor) \*/,\n",
        "",
        text,
        flags=re.M,
    )
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    flavor_header = re.compile(
        r"\t\t[A-F0-9]{24} /\* (?:Debug|Profile|Release)-(?:villa|kuafor) \*/ = \{"
    )
    while i < len(lines):
        line = lines[i]
        if flavor_header.match(line):
            depth = line.count("{") - line.count("}")
            i += 1
            while i < len(lines) and depth > 0:
                depth += lines[i].count("{") - lines[i].count("}")
                i += 1
            continue
        out.append(line)
        i += 1
    pbx.write_text("".join(out))


def strip_ios_flavors(dest: Path, bundle: str, display: str, icon: str) -> None:
    schemes = dest / "ios/Runner.xcodeproj/xcshareddata/xcschemes"
    for name in ("villa.xcscheme", "kuafor.xcscheme"):
        p = schemes / name
        if p.exists():
            p.unlink()
    pbx = dest / "ios/Runner.xcodeproj/project.pbxproj"
    text = pbx.read_text()
    text = text.replace("com.musaitvillam.kuafor", bundle)
    text = text.replace("com.musaitvillam.villa", bundle)
    text = re.sub(r'INFOPLIST_KEY_CFBundleDisplayName = "[^"]*";', f'INFOPLIST_KEY_CFBundleDisplayName = "{display}";', text)
    text = re.sub(r'APP_DISPLAY_NAME = "[^"]*";', f'APP_DISPLAY_NAME = "{display}";', text)
    text = re.sub(r"ASSETCATALOG_COMPILER_APPICON_NAME = [^;]+;", f"ASSETCATALOG_COMPILER_APPICON_NAME = {icon};", text)
    pbx.write_text(text)
    strip_flavor_pbx(pbx)
    plist = dest / "ios/Runner/Info.plist"
    plist_text = plist.read_text()
    plist_text = plist_text.replace("$(APP_DISPLAY_NAME)", display)
    plist_text = plist_text.replace("$(APP_BUNDLE_NAME)", display.replace(" ", ""))
    plist.write_text(plist_text)
    pod = dest / "ios/Podfile"
    pod.write_text(
        pod.read_text().replace(
            """project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
  'Debug-villa' => :debug,
  'Profile-villa' => :release,
  'Release-villa' => :release,
  'Debug-kuafor' => :debug,
  'Profile-kuafor' => :release,
  'Release-kuafor' => :release,
}""",
            """project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}""",
        )
    )


def write_flutter_xcconfig(dest: Path, display: str) -> None:
    bundle_name = display.replace(" ", "")
    for name in ("Debug.xcconfig", "Release.xcconfig"):
        p = dest / "ios/Flutter" / name
        if not p.exists():
            continue
        text = p.read_text()
        text = re.sub(r"^APP_DISPLAY_NAME=.*$", f"APP_DISPLAY_NAME={display}", text, flags=re.M)
        text = re.sub(r"^APP_BUNDLE_NAME=.*$", f"APP_BUNDLE_NAME={bundle_name}", text, flags=re.M)
        p.write_text(text)


def main() -> None:
    copy_admin()
    copy_customer()

    kuafor = ROOT / "kuafor"
    villa = ROOT / "villa"
    rsync_app(kuafor)
    rsync_app(villa)
    write_app_main(kuafor, "kuafor", "Kuaför randevu — işletme ve müşteri")
    write_app_main(villa, "villa", "Villa rezervasyon — işletme ve müşteri")
    simplify_android(kuafor, "com.musaitvillam.kuafor", "Kuaför Randevu", "#BE185D")
    simplify_android(villa, "com.musaitvillam.villa", "Müsait Villam", "#0F766E")
    strip_ios_flavors(kuafor, "com.musaitvillam.kuafor", "Kuaför Randevu", "AppIcon-kuafor")
    strip_ios_flavors(villa, "com.musaitvillam.villa", "Müsait Villam", "AppIcon-villa")
    write_flutter_xcconfig(kuafor, "Kuaför Randevu")
    write_flutter_xcconfig(villa, "Müsait Villam")
    print("apps ready")


if __name__ == "__main__":
    main()
