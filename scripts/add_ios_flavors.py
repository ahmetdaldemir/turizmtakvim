#!/usr/bin/env python3
"""Add villa/kuafor Xcode schemes and build configurations for Flutter flavors."""

from __future__ import annotations

import hashlib
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CUSTOMER = {
    "villa": {
        "bundle": "com.musaitvillam.villa",
        "display": "Villa Rezervasyon",
        "bundle_name": "VillaRezervasyon",
        "icon": "AppIcon-villa",
    },
    "kuafor": {
        "bundle": "com.musaitvillam.kuafor",
        "display": "Kuaför Randevu",
        "bundle_name": "KuaforRandevu",
        "icon": "AppIcon-kuafor",
    },
}

MOBILE = {
    "villa": {
        "bundle": "com.musaitvillam.villa.yonetim",
        "display": "Villa Yönetim",
        "bundle_name": "VillaYonetim",
        "icon": "AppIcon-villa",
    },
    "kuafor": {
        "bundle": "com.musaitvillam.kuafor.yonetim",
        "display": "Kuaför Yönetim",
        "bundle_name": "KuaforYonetim",
        "icon": "AppIcon-kuafor",
    },
}

CONFIG_RE = re.compile(
    r"\t\t([0-9A-F]{24}) /\* (Debug|Release|Profile) \*/ = \{\n"
    r"\t\t\tisa = XCBuildConfiguration;\n"
    r"(.*?)\n"
    r"\t\t\tname = (Debug|Release|Profile);\n"
    r"\t\t\};",
    re.S,
)


def uid(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def apply_flavor_settings(body: str, flavor: dict) -> str:
    if "TEST_HOST" in body:
        body = re.sub(
            r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
            f'PRODUCT_BUNDLE_IDENTIFIER = {flavor["bundle"]}.RunnerTests;',
            body,
        )
        return body
    if "PRODUCT_BUNDLE_IDENTIFIER" not in body:
        return body
    body = re.sub(
        r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
        f'PRODUCT_BUNDLE_IDENTIFIER = {flavor["bundle"]};',
        body,
    )
    if "INFOPLIST_KEY_CFBundleDisplayName" in body:
        body = re.sub(
            r'INFOPLIST_KEY_CFBundleDisplayName = "[^"]*";',
            f'INFOPLIST_KEY_CFBundleDisplayName = "{flavor["display"]}";',
            body,
        )
    else:
        body = body.replace(
            "INFOPLIST_FILE = Runner/Info.plist;",
            "INFOPLIST_FILE = Runner/Info.plist;\n"
            f'\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "{flavor["display"]}";',
        )
    if "ASSETCATALOG_COMPILER_APPICON_NAME" in body:
        body = re.sub(
            r"ASSETCATALOG_COMPILER_APPICON_NAME = [^;]+;",
            f'ASSETCATALOG_COMPILER_APPICON_NAME = {flavor["icon"]};',
            body,
        )
    extras = (
        f'\t\t\t\tAPP_DISPLAY_NAME = "{flavor["display"]}";\n'
        f'\t\t\t\tAPP_BUNDLE_NAME = {flavor["bundle_name"]};\n'
    )
    if "APP_DISPLAY_NAME =" in body:
        body = re.sub(r'APP_DISPLAY_NAME = "[^"]*";', f'APP_DISPLAY_NAME = "{flavor["display"]}";', body)
        body = re.sub(r"APP_BUNDLE_NAME = [^;]+;", f'APP_BUNDLE_NAME = {flavor["bundle_name"]};', body)
    else:
        body = body.replace(
            "buildSettings = {\n",
            "buildSettings = {\n" + extras,
            1,
        )
    return body


def patch_pbxproj(path: Path, flavors: dict) -> None:
    text = path.read_text()
    if "Debug-villa" in text:
        print(f"skip flavors (already present): {path}")
        return

    new_blocks: list[str] = []
    clones: dict[str, list[tuple[str, str]]] = {}

    def repl(match: re.Match) -> str:
        old_id, name, body, name2 = match.group(1), match.group(2), match.group(3), match.group(4)
        assert name == name2
        clones.setdefault(old_id, [])
        for flavor_name, flavor in flavors.items():
            new_name = f"{name}-{flavor_name}"
            new_id = uid(f"{path}:{old_id}:{new_name}")
            new_body = apply_flavor_settings(body, flavor)
            new_blocks.append(
                f"\t\t{new_id} /* {new_name} */ = {{\n"
                f"\t\t\tisa = XCBuildConfiguration;\n"
                f"{new_body}\n"
                f"\t\t\tname = {new_name};\n"
                f"\t\t}};"
            )
            clones[old_id].append((new_id, new_name))
        return match.group(0)

    text2, n = CONFIG_RE.subn(repl, text)
    if n == 0:
        raise SystemExit(f"No configurations found in {path}")

    text2 = text2.replace(
        "/* End XCBuildConfiguration section */",
        "\n".join(new_blocks) + "\n/* End XCBuildConfiguration section */",
    )
    for old_id, pairs in clones.items():
        extra = "".join(f"\t\t\t\t{nid} /* {nname} */,\n" for nid, nname in pairs)
        text2 = re.sub(rf"(\t\t\t\t{old_id} /\* [^*]+ \*/,\n)", rf"\1{extra}", text2, count=1)
    path.write_text(text2)
    print(f"flavors added: {path} ({n} base configs)")


def write_scheme(src: Path, dest: Path, flavor: str) -> None:
    xml = src.read_text()
    xml = xml.replace('buildConfiguration = "Debug"', f'buildConfiguration = "Debug-{flavor}"')
    xml = xml.replace('buildConfiguration = "Release"', f'buildConfiguration = "Release-{flavor}"')
    xml = xml.replace('buildConfiguration = "Profile"', f'buildConfiguration = "Profile-{flavor}"')
    dest.write_text(xml)
    print(f"scheme: {dest.name}")


def patch_podfile(path: Path) -> None:
    text = path.read_text()
    if "Debug-villa" in text:
        return
    old = """project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}"""
    new = """project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
  'Debug-villa' => :debug,
  'Profile-villa' => :release,
  'Release-villa' => :release,
  'Debug-kuafor' => :debug,
  'Profile-kuafor' => :release,
  'Release-kuafor' => :release,
}"""
    if old not in text:
        raise SystemExit(f"Podfile mapping not found: {path}")
    path.write_text(text.replace(old, new))
    print(f"podfile: {path}")


def patch_xcconfig(path: Path, display: str, bundle_name: str) -> None:
    text = path.read_text()
    if "APP_DISPLAY_NAME" in text:
        return
    path.write_text(
        text.rstrip()
        + f"\nAPP_DISPLAY_NAME={display}\nAPP_BUNDLE_NAME={bundle_name}\n"
    )


def process_app(ios_dir: Path, flavors: dict, default_display: str, default_bundle_name: str) -> None:
    pbx = ios_dir / "Runner.xcodeproj/project.pbxproj"
    patch_pbxproj(pbx, flavors)
    schemes = ios_dir / "Runner.xcodeproj/xcshareddata/xcschemes"
    runner = schemes / "Runner.xcscheme"
    for flavor in flavors:
        write_scheme(runner, schemes / f"{flavor}.xcscheme", flavor)
    patch_podfile(ios_dir / "Podfile")
    patch_xcconfig(ios_dir / "Flutter/Debug.xcconfig", default_display, default_bundle_name)
    patch_xcconfig(ios_dir / "Flutter/Release.xcconfig", default_display, default_bundle_name)


def main() -> None:
    process_app(
        ROOT / "customer/ios",
        CUSTOMER,
        "Kuaför Randevu",
        "KuaforRandevu",
    )
    process_app(
        ROOT / "mobile/ios",
        MOBILE,
        "Villa Yönetim",
        "VillaYonetim",
    )


if __name__ == "__main__":
    main()
