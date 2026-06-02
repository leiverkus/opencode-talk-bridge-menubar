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
the bridge itself. Status comes from the bridge's `status.json` (single
source of truth).

Agent-only app (`LSUIElement`), so no Dock icon, no in-app menu bar.

## Get the bridge

Install the bridge from PyPI (no git clone needed):

```sh
uv tool install opencode-talk-bridge
# or: pipx install opencode-talk-bridge
```

Both place the console script at `~/.local/bin/opencode-talk-bridge`, which
is the app's default binary path.

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

On first launch, if the bridge binary can't be found, a **setup window**
appears automatically:

1. Confirm the **bridge binary** path (defaults to
   `~/.local/bin/opencode-talk-bridge`) and the **config directory**
   (defaults to `~/.config/opencode-talk-bridge`, where `.env`,
   `status.json`, and `bridge.sqlite3` live).
2. The window shows live checks: an executable bridge binary (required),
   the config dir (created on demand), and a `.env` recommendation
   (credentials live there; the app never touches them).
3. Optionally **Konfig-Ordner anlegen** and **.env öffnen**, then
   **plist installieren** to write the launchd agent, and **Fertig**.

The setup window is self-healing: it reappears on the next launch as long
as the bridge binary can't be resolved, so a wrong or moved path never
leaves the app silently broken. You can reopen it any time from the menu's
**Einrichtung…** item, and the same checks appear in
**Einstellungen → Bridge**.

## How it controls the bridge

- launchd label: `com.leiverkus.opencode-talk-bridge`
- The app **generates** the launchd plist itself (the PyPI wheel doesn't
  ship one) from the configured binary path, config dir, and log paths,
  then writes it to `~/Library/LaunchAgents/`. The plist's
  `ProgramArguments` run `<binary> --env-file <configdir>/.env` with
  `WorkingDirectory = <configdir>`, so the bridge finds its `.env`,
  `status.json`, and DB there.
- Start/stop go through `launchctl bootstrap gui/<uid> <plist>` and
  `launchctl bootout gui/<uid>/<label>`. A second start on an already-loaded
  service kicks it with `launchctl kickstart -k`.
- Status comes from `<configdir>/status.json`. The reader uses
  `DispatchSource` FS events for instant updates plus a 2 s timer fallback
  (atomic temp+rename writes invalidate a single FD watch).

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

UI is excluded — the 41 unit tests cover status decoding (all six states),
plist generation, the launchd-target string, the sleep-assertion lifecycle
(against a protocol mock), the wake-coordinator state machine, bridge-setup
validation (executable-bit aware), the status reader (initial read, atomic
replace, and `retarget` to a new path), and the service-state poller
(dedupe plus the forced re-publish that re-enables the menu after a failed
action).

### End-to-end (opt-in)

`E2EIntegrationTests` drives the real `BridgeService`/`SleepAssertion`
against the uv/pipx-installed bridge and the live launchd domain. It is
skipped unless `RUN_E2E=1`, so CI and normal runs never touch launchd:

```sh
uv tool install opencode-talk-bridge
RUN_E2E=1 swift test --filter E2EIntegrationTests
```

It installs the generated plist, `bootstrap`s the service, confirms it is
loaded, reads `status.json`, `bootout`s, and verifies the IOPM assertion
shows up in `pmset -g assertions` and is released — cleaning up after
itself.

## Release packaging

```sh
Scripts/build-app.sh   # → dist/TalkBridgeMenubar.app
Scripts/sign.sh        # codesign; ad-hoc by default
Scripts/make-dmg.sh    # → dist/TalkBridgeMenubar.dmg
Scripts/notarize.sh    # no-op unless APPLE_NOTARY_* are set
```

`.github/workflows/release.yml` runs the same chain on a `v*` tag push and
uploads the DMG as a release asset.

The pipeline is notarization-ready without restructuring: `sign.sh` honours
`SIGN_IDENTITY` (default `-` = ad-hoc) and `notarize.sh` is a no-op until the
notary credentials exist. To ship a notarized build, add a Developer ID to
the runner keychain and set these repo secrets, then re-tag:

```
SIGN_IDENTITY          "Developer ID Application: … (TEAMID)"
APPLE_NOTARY_APPLE_ID  Apple ID e-mail
APPLE_NOTARY_TEAM_ID   10-char team id
APPLE_NOTARY_PASSWORD  app-specific password
```

Locally you can do the same: `SIGN_IDENTITY="…" Scripts/sign.sh && Scripts/make-dmg.sh && APPLE_NOTARY_APPLE_ID=… APPLE_NOTARY_TEAM_ID=… APPLE_NOTARY_PASSWORD=… Scripts/notarize.sh`.

## License

MIT. © 2026 Patrick Leiverkus.
