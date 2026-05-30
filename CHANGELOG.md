# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-30

Initial release. Native macOS menu-bar app that controls the
[`opencode-talk-bridge`](https://github.com/leiverkus/opencode-talk-bridge)
polling service via launchd and keeps the Mac awake while it runs.

### Added
- Agent-only app (`LSUIElement`) with `NSStatusItem` showing live bridge
  state via SF Symbols: `starting`, `polling`, `working`, `opencode_down`,
  `error`, `stopped`.
- `BridgeStatusReader` watching `status.json` via `DispatchSource` FS
  events with a 2 s timer fallback (handles atomic temp+rename writes).
- `BridgeService` wrapping `launchctl bootstrap`/`bootout`/`kickstart` for
  the service label `com.leiverkus.opencode-talk-bridge`.
- `PlistTemplate` rewriter that substitutes the four absolute paths
  (venv binary, `--env-file`, `WorkingDirectory`, stdout/stderr logs) in
  the bridge's plist template before installing to
  `~/Library/LaunchAgents/`.
- `SleepAssertion` RAII wrapper around `IOPMAssertionCreateWithName`
  (`kIOPMAssertPreventUserIdleSystemSleep`), with a `PowerAssertionAPI`
  protocol for testability.
- `WakeCoordinator` with three modes: `coupled` (default — assertion
  follows bridge live state), `always`, `off`.
- SwiftUI Settings window with four tabs: Bridge (repo path picker,
  plist install, open `.env`), Wachhalten (mode picker), Allgemein
  (`SMAppService` login item, log shortcuts), Info (versions, repo links).
- "Log öffnen" submenu on the status bar plus matching buttons in the
  Settings → Allgemein tab.
- 26 unit tests covering status decoding (all six states + null
  `last_error` + unknown state rejection), plist rewrite, service-target
  composition, sleep-assertion lifecycle against a protocol mock,
  wake-coordinator state transitions, and the status reader against a
  temp file (initial read + atomic replace).
- GitHub Actions: `ci.yml` (`swift build` + `swift test` on macos-14)
  and tag-triggered `release.yml` that runs the build / sign / DMG
  scripts and uploads the artifact as a release asset.
- Release scripts: `Scripts/build-app.sh` (assembles the `.app`
  bundle from the SPM executable), `Scripts/sign-adhoc.sh`
  (`codesign --sign -` with hardened runtime), `Scripts/make-dmg.sh`
  (`hdiutil` with an `Applications` symlink for drag-to-install).
- README install section covering the Gatekeeper first-launch flow
  (`xattr -dr com.apple.quarantine` or right-click → Öffnen) since the
  DMG is ad-hoc signed, not notarized.

### Known limitations
- No app icon yet (`Resources/AppIcon.icns` slot is empty; the bundle
  builds without it).
- Release pipeline is ad-hoc signed only; swap-in points for a Developer
  ID + `notarytool` are marked as TODO in `release.yml`.

[Unreleased]: https://github.com/leiverkus/opencode-talk-bridge-menubar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/leiverkus/opencode-talk-bridge-menubar/releases/tag/v0.1.0
