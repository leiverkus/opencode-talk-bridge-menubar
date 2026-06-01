#!/usr/bin/env bash
# Code-sign the .app bundle.
#
# Identity is taken from SIGN_IDENTITY (default "-" = ad-hoc). Switching to a
# real Developer ID is a one-liner at call time — no script change needed:
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/sign.sh
#
# Ad-hoc-signed downloads still trip Gatekeeper on first launch (see the
# README install section); a Developer ID + notarization (Scripts/notarize.sh)
# is what removes that prompt.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_BUNDLE="dist/TalkBridgeMenubar.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "missing $APP_BUNDLE — run build-app.sh first" >&2
  exit 1
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "→ ad-hoc signing (SIGN_IDENTITY unset)"
else
  echo "→ signing with identity: $SIGN_IDENTITY"
fi

codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

echo "→ verifying"
codesign --verify --verbose=2 "$APP_BUNDLE"

echo "✓ signed $APP_BUNDLE"
