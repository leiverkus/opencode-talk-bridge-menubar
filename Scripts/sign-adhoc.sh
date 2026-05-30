#!/usr/bin/env bash
# Ad-hoc-sign the .app bundle. No Apple Developer ID required; downloaded
# copies will still trigger Gatekeeper on first launch (see README install
# section). TODO: swap `--sign -` for a Developer ID and add notarization
# once a paid Apple account is in play.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_BUNDLE="dist/TalkBridgeMenubar.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "missing $APP_BUNDLE — run build-app.sh first" >&2
  exit 1
fi

echo "→ codesign --force --deep --sign - --options runtime"
codesign --force --deep --sign - --options runtime "$APP_BUNDLE"

echo "→ verifying"
codesign --verify --verbose=2 "$APP_BUNDLE"

echo "✓ ad-hoc signed $APP_BUNDLE"
