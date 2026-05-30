#!/usr/bin/env bash
# Pack the signed .app into a drag-to-install .dmg with an Applications symlink.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="TalkBridgeMenubar"
APP_BUNDLE="dist/$APP_NAME.app"
DMG_PATH="dist/$APP_NAME.dmg"
STAGE="dist/dmg-stage"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "missing $APP_BUNDLE — run build-app.sh first" >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "→ hdiutil create $DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE"
echo "✓ wrote $DMG_PATH"
