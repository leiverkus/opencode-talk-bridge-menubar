#!/usr/bin/env bash
# Notarize the DMG with Apple's notary service and staple the ticket.
#
# This is a NO-OP unless all four notary credentials are present in the
# environment, so the default ad-hoc release pipeline calls it harmlessly:
#
#   APPLE_NOTARY_APPLE_ID    Apple ID e-mail
#   APPLE_NOTARY_TEAM_ID     10-char team id
#   APPLE_NOTARY_PASSWORD    app-specific password (not your Apple ID password)
#   APPLE_NOTARY_PROFILE     (optional) keychain profile name; if set, used
#                            instead of the id/password trio
#
# Requires the app/DMG to be signed with a Developer ID (see Scripts/sign.sh
# with SIGN_IDENTITY); ad-hoc-signed artifacts cannot be notarized.

set -euo pipefail

cd "$(dirname "$0")/.."

DMG_PATH="dist/TalkBridgeMenubar.dmg"

have_creds() {
  [[ -n "${APPLE_NOTARY_PROFILE:-}" ]] && return 0
  [[ -n "${APPLE_NOTARY_APPLE_ID:-}" && -n "${APPLE_NOTARY_TEAM_ID:-}" \
     && -n "${APPLE_NOTARY_PASSWORD:-}" ]]
}

if ! have_creds; then
  echo "→ notarization skipped (no APPLE_NOTARY_* credentials set)"
  exit 0
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "missing $DMG_PATH — run make-dmg.sh first" >&2
  exit 1
fi

echo "→ submitting $DMG_PATH to notary service (this can take minutes)"
if [[ -n "${APPLE_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
else
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_NOTARY_APPLE_ID" \
    --team-id "$APPLE_NOTARY_TEAM_ID" \
    --password "$APPLE_NOTARY_PASSWORD" --wait
fi

echo "→ stapling ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "✓ notarized and stapled $DMG_PATH"
