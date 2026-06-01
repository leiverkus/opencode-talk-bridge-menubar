#!/usr/bin/env bash
# Regenerate the app icon from the master PNG.
#   Resources/AppIcon-candidate.png  (master/preview, drawn by make-icon.py)
#   Resources/AppIcon.iconset/       (intermediate size set)
#   Resources/AppIcon.icns           (the real macOS app icon)

set -euo pipefail

cd "$(dirname "$0")/.."

MASTER="Resources/AppIcon-candidate.png"
ICONSET="Resources/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"

# Draw the master if it's missing (idempotent — safe to re-run).
if [[ ! -f "$MASTER" ]]; then
  echo "→ master missing, drawing it"
  python3 Scripts/make-icon.py
fi

echo "→ building $ICONSET"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# name                       size
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png      128
gen icon_128x128@2x.png   256
gen icon_256x256.png      256
gen icon_256x256@2x.png   512
gen icon_512x512.png      512
gen icon_512x512@2x.png   1024

echo "→ building $ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "✓ icon regenerated ($ICNS)"
