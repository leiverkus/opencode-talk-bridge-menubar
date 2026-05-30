#!/usr/bin/env bash
# Build a release .app bundle from the SPM executable.
# Output: dist/TalkBridgeMenubar.app

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="TalkBridgeMenubar"
BUNDLE_ID="com.leiverkus.TalkBridgeMenubar"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "→ swift build -c release --arch arm64"
swift build -c release --arch arm64

BINARY_PATH="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"
if [[ ! -x "$BINARY_PATH" ]]; then
  echo "executable not found at $BINARY_PATH" >&2
  exit 1
fi

echo "→ assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# AppIcon.icns is optional; copy if present.
if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo "✓ built $APP_BUNDLE"
