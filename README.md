# opencode-talk-bridge-menubar

[![CI](https://github.com/leiverkus/opencode-talk-bridge-menubar/actions/workflows/ci.yml/badge.svg)](https://github.com/leiverkus/opencode-talk-bridge-menubar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/leiverkus/opencode-talk-bridge-menubar?sort=semver)](https://github.com/leiverkus/opencode-talk-bridge-menubar/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)](#build)
[![Swift](https://img.shields.io/badge/swift-5.10%2B-orange?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A native macOS menu-bar app (Swift) that

1. **keeps the Mac awake** (`IOPMAssertion`) while the Python polling bridge
   [`opencode-talk-bridge`](https://github.com/leiverkus/opencode-talk-bridge) is
   running, and
2. **starts/stops/monitors** that bridge as a launchd user agent, showing
   its live state (`starting` / `polling` / `working` / `opencode_down` /
   `error` / `stopped`) in the menu-bar icon.

The app is a thin controller — credentials and the polling logic live in
the bridge repo. Status comes from the bridge's `status.json` (single source
of truth).

Agent-only app (`LSUIElement`), so no Dock icon, no in-app menu bar.

## Installation

The release `.dmg` is **ad-hoc signed**, not notarized (the project has no
paid Apple Developer Program account). Gatekeeper blocks the first launch
of an unnotarized app downloaded from the internet. Either of the following
clears it once:

- Right-click `TalkBridgeMenubar.app` → **Öffnen** → confirm **Öffnen** in
  the dialog. (Easiest path.)
- Or in Terminal:
  ```sh
  xattr -dr com.apple.quarantine /Applications/TalkBridgeMenubar.app
  ```

The source is on GitHub and the build pipeline is in
[`.github/workflows/release.yml`](.github/workflows/release.yml) — no
hidden binaries.

## First run / configuration

On first launch the app doesn't know where your `opencode-talk-bridge`
checkout lives, so a **setup window** appears automatically:

1. Pick the bridge repo folder (the one containing `.venv/` and
   `deploy/com.leiverkus.opencode-talk-bridge.plist`).
2. The window shows live checks for the required artifacts — repo dir,
   plist template, venv binary — plus a recommendation to have a `.env`
   (credentials live there; the app never touches them).
3. Click **plist installieren** to write the launchd agent, then **Fertig**.

The setup window is self-healing: it reappears on the next launch as long
as the configured path can't be resolved, so a wrong or moved repo never
leaves the app silently broken. You can reopen it any time from the menu's
**Einrichtung…** item, and the same checks appear in
**Einstellungen → Bridge**.

## How it controls the bridge

- launchd label: `com.leiverkus.opencode-talk-bridge`
- The app reads the plist template from
  `<bridge-repo>/deploy/com.leiverkus.opencode-talk-bridge.plist`, rewrites
  the four absolute paths (venv binary, `--env-file`, `WorkingDirectory`,
  stdout/stderr log paths) from the app's settings, and installs the result
  to `~/Library/LaunchAgents/`.
- Start/stop go through `launchctl bootstrap gui/<uid> <plist>` and
  `launchctl bootout gui/<uid>/<label>`. A second start on an already-loaded
  service kicks it with `launchctl kickstart -k`.
- Status comes from `<bridge-repo>/status.json` (file path configurable via
  the bridge's `STATUS_FILE` env). The reader uses `DispatchSource` FS
  events for instant updates plus a 2 s timer fallback (atomic
  temp+rename writes invalidate a single FD watch).

The launchd-service variant was chosen over a child process so the bridge
survives an app restart and is independently observable via `launchctl
print gui/$(id -u)/com.leiverkus.opencode-talk-bridge`.

## Build

Requires Swift 5.10+ and macOS 13+.

```sh
swift build
swift run TalkBridgeMenubar
```

The app appears as a status item in the menu bar.

## Tests

```sh
swift test
```

UI is excluded — tests cover status decoding, plist rewrite, the
launchd-target string, the sleep-assertion lifecycle (against a protocol
mock), and the wake-coordinator state machine.

## Release packaging

```sh
Scripts/build-app.sh   # → dist/TalkBridgeMenubar.app
Scripts/sign-adhoc.sh  # codesign --sign -
Scripts/make-dmg.sh    # → dist/TalkBridgeMenubar.dmg
```

`.github/workflows/release.yml` runs the same chain on a `v*` tag push and
uploads the DMG as a release asset. A TODO marker in that workflow points
at the lines to change once a Developer ID + notarization becomes
available.

## License

MIT. © 2026 Patrick Leiverkus.
