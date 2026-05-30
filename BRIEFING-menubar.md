# Briefing: `opencode-talk-bridge-menubar` (macOS Menüleisten-App)

## Ziel

Neues, eigenständiges GitHub-Repo (`leiverkus/opencode-talk-bridge-menubar`).
Eine native macOS-Menüleisten-App (Swift), die zwei Dinge tut:

1.  **Den Mac wachhalten** (caffeine-artig), damit die Polling-Bridge ununterbrochen laufen kann, auch wenn der Rechner sonst in den Ruhezustand ginge.
2.  **Die Polling-Bridge starten/stoppen/überwachen** (`opencode-talk-bridge`, separates Python-Repo) und ihren Status in der Menüleiste anzeigen.

Zielsystem: macOS (Apple Silicon, M3 Max).
Solo-Projekt, kein App-Store-Zwang — aber sauber signier-/notarisierbar, damit Gatekeeper nicht meckert.

## Warum Swift (festgelegt)

Wachhalten und Prozess-/Service-Management sind native macOS-Domäne (`IOPMAssertion` / `caffeinate`, `NSStatusItem`, launchd).
Eine Python-Menübar-App (rumps/py2app) würde Bündelungs-, Signierungs- und Notarisierungsschmerzen bringen und eine fette .app erzeugen.
Die Bridge bleibt Python; die App bettet sie **nicht ein**, sondern **steuert** sie.

## Funktionsumfang

### Menüleisten-Icon (`NSStatusItem`)

- Status-Icon, das den Bridge-Zustand spiegelt: gestoppt / läuft & pollt / Fehler / OpenCode nicht erreichbar. Unterscheidbare Symbole (SF Symbols) + Tooltip.
- Menü mit: Bridge starten/stoppen, Wachhalten an/aus, „OpenCode-Server-Status", Log öffnen, Einstellungen, Beenden.

### Wachhalten (caffeine-artig)

- Schlaf verhindern über die korrekte macOS-API. Bevorzugt **`IOPMAssertionCreateWithName`** (`kIOPMAssertionTypePreventUserIdleSystemSleep` bzw. Display-Sleep je nach gewünschtem Verhalten) statt einen `caffeinate`-Subprozess zu starten — robuster und ohne Kindprozess-Verwaltung. `caffeinate` als Fallback dokumentieren.
- Toggle: nur wachhalten, solange die Bridge läuft, ODER dauerhaft (Nutzerpräferenz). Standard sinnvoll wählen: Wachhalten gekoppelt an Bridge-Lauf.
- Sauber freigeben (`IOPMAssertionRelease`) beim Stoppen/Beenden, sonst bleibt der Mac dauerhaft wach.

### Bridge-Steuerung

Entscheidung: **launchd-User-Service** statt direktem Kindprozess.
Begründung: Die Bridge soll einen App-Neustart überleben und unabhängig laufen; die App schaltet den Service nur an/aus und liest Status.

- App lädt/entlädt bzw. started/stoppt den launchd-Service der Bridge (`launchctl bootstrap`/`bootout` oder `kickstart`). Die Beispiel-plist liefert das Bridge-Repo (`deploy/…plist`); die App muss wissen, wie sie sie ansteuert.
- Falls launchd-Verdrahtung zu schwergewichtig wird, Fallback: Bridge als überwachter Kindprozess (`Process`), mit Neustart bei Absturz — aber das ist Plan B; im README die gewählte Variante klar benennen.

### Status-Anzeige

- Status der Bridge auslesen über die im Bridge-Repo definierte **Status-Schnittstelle** (Status-File JSON oder localhost-Socket/Port — siehe Bridge-README). Die App pollt dieses Status-File in Intervallen und aktualisiert Icon/Menü.
- OpenCode-Server-Erreichbarkeit ebenfalls anzeigen (kommt aus dem Bridge-Status, nicht selbst prüfen — Single Source of Truth ist die Bridge).

### Einstellungen

- Pfade/Port der Bridge bzw. des launchd-Service-Labels.
- Wachhalten-Modus (gekoppelt / dauerhaft / nur Display).
- Optional: „beim Login starten" (App selbst als Login-Item, `SMAppService`).

## Technik

- Swift, SwiftUI für Settings-Fenster + AppKit für `NSStatusItem` (MenuBarExtra in reinem SwiftUI ist möglich, aber für Status-Icon-Feinheiten ist AppKit-Interop oft pragmatischer — Entscheidung dem Implementierer überlassen, im README begründen).
- Kein Dock-Icon (`LSUIElement` / Agent-App).
- Xcode-Projekt **oder** Swift Package Manager-Executable mit App-Bundle — SPM bevorzugt, wenn ohne Xcode-GUI baubar (CI-freundlich); sonst `.xcodeproj`.
- Signierung/Notarisierung: zumindest dokumentieren, idealerweise ad-hoc-signierbar für lokalen Gebrauch; Hardened Runtime beachten, falls Notarisierung gewünscht.

## Repo-Struktur (Vorschlag, SPM-Variante)

```         
opencode-talk-bridge-menubar/
├── Package.swift
├── Sources/TalkBridgeMenubar/
│   ├── App.swift              # @main, LSUIElement-Agent
│   ├── StatusItemController.swift   # NSStatusItem, Menü, Icon-State
│   ├── SleepAssertion.swift   # IOPMAssertion wachhalten
│   ├── BridgeService.swift    # launchctl-Steuerung der Bridge
│   ├── BridgeStatus.swift     # liest Status-File/Socket der Bridge
│   └── Settings/              # SwiftUI-Einstellungen
├── Tests/
├── README.md                  # gewählte launchd-Variante + Build/Signier-Hinweise
├── LICENSE                    # MIT (Copyright Patrick Leiverkus)
└── .github/workflows/ci.yml   # swift build + swift test (macOS runner)
```

## Tests + CI

- `swift test` für die testbaren Teile (Status-Parsing, Service-Label-Logik, Assertion-Lebenszyklus mit Mock). UI-Teile pragmatisch ausklammern.
- GitHub Actions auf macOS-Runner: `swift build` + `swift test`. (Keine Multi-Version-Matrix wie bei Python nötig; ggf. gegen zwei aktuelle Swift/Xcode-Versionen.)

## Release (GitHub, ohne Apple Developer Program)

Ziel: ein ladbares `.dmg` als GitHub-Release, **ohne** bezahlte Apple-Lizenz.
Das ist möglich; der Preis ist eine Gatekeeper-Hürde beim ersten Start auf fremden Macs, die im README erklärt werden muss.

### Build & Signierung

- Release-Build der `.app` aus dem SPM-Executable bündeln (App-Bundle-Struktur: `Contents/MacOS`, `Info.plist` mit `LSUIElement=true`, Icon).
- **Ad-hoc-Signierung**: `codesign --force --deep --sign - --options runtime TalkBridgeMenubar.app`. Kein Zertifikat, keine Apple-ID nötig. (Alternativ Signierung über kostenloses „Personal Team", falls `SMAppService`-Login-Item sonst zickt — siehe Technik-Abschnitt.)
- `.dmg` packen (z.B. `hdiutil create` oder `create-dmg`), mit Applications-Symlink fürs Drag-to-install.

### Was NICHT geht (und warum)

- **Keine Notarisierung** ohne Developer ID (\$99/Jahr). Heruntergeladene, nicht-notarisierte Apps bekommen das Quarantäne-Flag; Gatekeeper blockt den ersten Start. Auf Apple Silicon ist das verbindlich.

### README-Pflichtabschnitt „Installation"

Klare Anleitung für den ersten Start, sonst wirkt die App kaputt:

- Empfohlen: Rechtsklick auf die App → „Öffnen" → im Dialog „Öffnen" bestätigen (einmalig), **oder**
- Terminal: `xattr -dr com.apple.quarantine /Applications/TalkBridgeMenubar.app`
- Kurzer, ehrlicher Hinweis, dass die App nicht notarisiert ist (Hobby-/Uni-Tool) und der Quellcode einsehbar ist — schafft Vertrauen statt „nicht verifizierter Entwickler"-Schreck.

### Release-Automation (optional)

- GitHub-Actions-Workflow (`release.yml`, tag-getriggert) auf macOS-Runner: Release-Build → ad-hoc-signieren → `.dmg` packen → als Release-Asset anhängen.
- Den Workflow so bauen, dass ein späterer Wechsel zu echter Signierung/Notarisierung nur das Hinzufügen von Secrets (Zertifikat, Notarytool-Credentials) erfordert, ohne die Pipeline umzustellen. Im Workflow als TODO markieren.

## Abhängigkeiten zwischen den Repos

- Die App ist auf die **Status-Schnittstelle** der Bridge angewiesen (Status-File/Socket-Format). Dieses Format ist im Bridge-README die Quelle der Wahrheit; die App implementiert nur den Leser. Falls das Format dort noch nicht final ist, hier zunächst gegen ein dokumentiertes Beispiel-JSON entwickeln und im README markieren.
- Die App kennt den launchd-Service-Namen/-plist der Bridge — konsistent mit `deploy/…plist` im Bridge-Repo halten.

## Reihenfolge

1.  Skeleton: Agent-App ohne Dock, leeres `NSStatusItem` mit Menü
2.  Wachhalten (IOPMAssertion) + Toggle, sauberes Release
3.  Bridge-Status-Datei lesen + Icon-State mappen (gegen Beispiel-JSON)
4.  launchd-Steuerung (start/stop) der Bridge
5.  Einstellungen + Login-Item
6.  README (Build, Signierung, gewählte launchd-Variante, **Installation/Quarantäne-Hinweis**), CI
7.  Release-Packaging: `.app`-Bundle → ad-hoc-signieren → `.dmg`, optional `release.yml`
8.  `git init`, Commit, Push nach `leiverkus/opencode-talk-bridge-menubar`

## Constraints

- Keine Secrets; die App verwaltet **keine** Talk-Credentials — die liegen bei der Bridge (`.env`/Keychain dort). Die App steuert nur Lebenszyklus + zeigt Status.
- IOPMAssertion immer freigeben (kein Wach-Leak).
- Code-Kommentare Englisch.