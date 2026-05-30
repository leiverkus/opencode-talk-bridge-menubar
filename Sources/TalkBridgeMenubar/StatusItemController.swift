import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let settings = AppSettings.shared
    private let wakeCoordinator: WakeCoordinator
    private let statusReader: BridgeStatusReader
    private let bridgeService: BridgeService
    private let settingsWindow: SettingsWindowController

    private var wakeMenuItems: [WakeMode: NSMenuItem] = [:]
    private var stateMenuItem: NSMenuItem!
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var currentStatus: BridgeStatus?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let assertion = SleepAssertion()
        wakeCoordinator = WakeCoordinator(assertion: assertion, mode: settings.wakeMode)
        statusReader = BridgeStatusReader(url: settings.statusFileURL)
        bridgeService = BridgeService(settings: settings)
        var statusBox: () -> BridgeStatus? = { nil }
        settingsWindow = SettingsWindowController(
            settings: settings,
            bridgeService: bridgeService,
            currentStatus: { statusBox() }
        )
        super.init()
        statusBox = { [weak self] in self?.currentStatus }
        applyIcon(for: nil)
        buildMenu()
        statusItem.menu = menu

        statusReader.onUpdate = { [weak self] status in
            self?.handleStatusUpdate(status)
        }
        statusReader.start()
    }

    private func applyIcon(for status: BridgeStatus?) {
        guard let button = statusItem.button else { return }
        let spec = StatusIcon.spec(for: status)
        button.image = StatusIcon.image(for: spec)
        button.toolTip = spec.tooltip
        button.setAccessibilityLabel("Talk Bridge")
        button.setAccessibilityValue(spec.tooltip)
    }

    private func buildMenu() {
        stateMenuItem = NSMenuItem()
        stateMenuItem.title = "Bridge: —"
        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)

        startItem = NSMenuItem(
            title: "Bridge starten",
            action: #selector(startBridge),
            keyEquivalent: ""
        )
        startItem.target = self
        menu.addItem(startItem)

        stopItem = NSMenuItem(
            title: "Bridge stoppen",
            action: #selector(stopBridge),
            keyEquivalent: ""
        )
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(.separator())

        let wakeHeader = NSMenuItem()
        wakeHeader.title = "Wachhalten"
        wakeHeader.isEnabled = false
        menu.addItem(wakeHeader)

        for mode in WakeMode.allCases {
            let item = NSMenuItem(
                title: "  " + mode.displayName,
                action: #selector(selectWakeMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (settings.wakeMode == mode) ? .on : .off
            wakeMenuItems[mode] = item
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let logMenuItem = NSMenuItem(title: "Log öffnen", action: nil, keyEquivalent: "")
        let logSubmenu = NSMenu()
        let stdoutItem = NSMenuItem(
            title: "stdout-Log",
            action: #selector(openStdoutLog),
            keyEquivalent: ""
        )
        stdoutItem.target = self
        logSubmenu.addItem(stdoutItem)
        let stderrItem = NSMenuItem(
            title: "stderr-Log",
            action: #selector(openStderrLog),
            keyEquivalent: ""
        )
        stderrItem.target = self
        logSubmenu.addItem(stderrItem)
        logMenuItem.submenu = logSubmenu
        menu.addItem(logMenuItem)

        let settingsItem = NSMenuItem(
            title: "Einstellungen…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Beenden",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openSettings() {
        settingsWindow.showWindow()
    }

    @objc private func openStdoutLog() {
        openLog(at: settings.stdoutLogURL)
    }

    @objc private func openStderrLog() {
        openLog(at: settings.stderrLogURL)
    }

    private func openLog(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            let alert = NSAlert()
            alert.messageText = "Log-Datei nicht gefunden"
            alert.informativeText = "\(url.path)\nDie Bridge hat noch nichts geschrieben oder läuft mit anderen Pfaden."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func handleStatusUpdate(_ status: BridgeStatus?) {
        currentStatus = status
        applyIcon(for: status)
        stateMenuItem.title = stateMenuTitle(for: status)

        // Menu enablement: any non-nil status that isn't `stopped` means a
        // launchd job exists and `Bridge stoppen` should be available.
        let serviceLoaded = status != nil && status?.state != .stopped
        startItem.isEnabled = !serviceLoaded
        stopItem.isEnabled = serviceLoaded

        // Wake coupling: only hold the assertion while the bridge is actively
        // working — opencode_down/error are parked states where sleeping is OK.
        wakeCoordinator.setBridgeRunning(status?.isLive ?? false)
    }

    @objc private func startBridge() {
        do {
            try bridgeService.start()
        } catch {
            presentError(error, title: "Bridge konnte nicht gestartet werden")
        }
    }

    @objc private func stopBridge() {
        do {
            try bridgeService.stop()
        } catch {
            presentError(error, title: "Bridge konnte nicht gestoppt werden")
        }
    }

    private func presentError(_ error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = String(describing: error)
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func stateMenuTitle(for status: BridgeStatus?) -> String {
        guard let s = status else { return "Bridge: kein Status" }
        return "Bridge: \(s.state.rawValue)"
    }

    @objc private func selectWakeMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = WakeMode(rawValue: raw) else { return }
        settings.wakeMode = mode
        wakeCoordinator.setMode(mode)
        for (m, item) in wakeMenuItems {
            item.state = (m == mode) ? .on : .off
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
