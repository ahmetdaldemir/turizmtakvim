#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/store/dist"
mkdir -p "$OUT"

echo "Kuaför AAB..."
(cd "$ROOT/kuafor" && flutter build appbundle --release)
cp "$ROOT/kuafor/build/app/outputs/bundle/release/app-release.aab" "$OUT/kuafor.aab"

echo "Villa AAB..."
(cd "$ROOT/villa" && flutter build appbundle --release)
cp "$ROOT/villa/build/app/outputs/bundle/release/app-release.aab" "$OUT/villa.aab"

echo "APK (iç test)..."
(cd "$ROOT/kuafor" && flutter build apk --release)
cp "$ROOT/kuafor/build/app/outputs/flutter-apk/app-release.apk" "$OUT/kuafor.apk"

(cd "$ROOT/villa" && flutter build apk --release)
cp "$ROOT/villa/build/app/outputs/flutter-apk/app-release.apk" "$OUT/villa.apk"

echo "Hazır: $OUT"
ls -lh "$OUT"
