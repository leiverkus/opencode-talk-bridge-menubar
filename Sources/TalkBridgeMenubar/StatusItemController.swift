import AppKit
import Combine

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let settings = AppSettings.shared
    private let wakeCoordinator: WakeCoordinator
    private let statusReader: BridgeStatusReader
    private let bridgeService: BridgeService
    private let servicePoller: ServiceStatePoller
    private let settingsWindow: SettingsWindowController
    private let onboardingWindow: OnboardingWindowController

    private var wakeMenuItems: [WakeMode: NSMenuItem] = [:]
    private var stateMenuItem: NSMenuItem!
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var currentStatus: BridgeStatus?
    private var isServiceLoaded: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    /// Serializes Start/Stop actions off the main thread so `launchctl`
    /// invocations (which can hang briefly) never freeze the menu bar.
    private let actionQueue = DispatchQueue(
        label: "com.leiverkus.TalkBridgeMenubar.actionqueue",
        qos: .userInitiated
    )

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let assertion = SleepAssertion()
        wakeCoordinator = WakeCoordinator(assertion: assertion, mode: settings.wakeMode)
        statusReader = BridgeStatusReader(url: settings.statusFileURL)
        bridgeService = BridgeService(settings: settings)
        servicePoller = ServiceStatePoller(service: bridgeService)
        var statusBox: () -> BridgeStatus? = { nil }
        let poller = servicePoller
        settingsWindow = SettingsWindowController(
            settings: settings,
            bridgeService: bridgeService,
            currentStatus: { statusBox() },
            onServiceChanged: { poller.refresh(force: true) }
        )
        onboardingWindow = OnboardingWindowController(
            settings: settings,
            bridgeService: bridgeService
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

        servicePoller.onUpdate = { [weak self] loaded in
            self?.handleServiceLoaded(loaded)
        }
        servicePoller.start()

        // Restart the watcher when the user changes the config dir (which is
        // where status.json lives). dropFirst skips the initial replay;
        // debounce coalesces typing so we don't re-attach on every keystroke.
        settings.$configDirPath
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.statusReader.retarget(to: self.settings.statusFileURL)
            }
            .store(in: &cancellables)

        // First-run / self-healing onboarding: if the bridge binary isn't
        // runnable, surface the setup window. No persisted skip flag — it
        // reappears next launch while the setup stays invalid.
        if !BridgeSetupValidator.validate(settings).isUsable {
            DispatchQueue.main.async { [weak self] in
                self?.onboardingWindow.showWindow()
            }
        }
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

        let setupItem = NSMenuItem(
            title: "Einrichtung…",
            action: #selector(openOnboarding),
            keyEquivalent: ""
        )
        setupItem.target = self
        menu.addItem(setupItem)

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

    @objc private func openOnboarding() {
        onboardingWindow.showWindow()
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

        // Wake coupling: only hold the assertion while the bridge is actively
        // working — opencode_down/error are parked states where sleeping is OK.
        wakeCoordinator.setBridgeRunning(status?.isLive ?? false)
    }

    /// launchd-truth signal: drives Start/Stop button enablement independently
    /// of status.json, which may be missing or stale while the service exists.
    private func handleServiceLoaded(_ loaded: Bool) {
        isServiceLoaded = loaded
        startItem.isEnabled = !loaded
        stopItem.isEnabled = loaded
    }

    @objc private func startBridge() {
        runAction(title: "Bridge konnte nicht gestartet werden") { [bridgeService] in
            try bridgeService.start()
        }
    }

    @objc private func stopBridge() {
        runAction(title: "Bridge konnte nicht gestoppt werden") { [bridgeService] in
            try bridgeService.stop()
        }
    }

    /// Run a launchctl-touching action on the background queue, then refresh
    /// the service-loaded signal and surface any error on the main thread.
    /// Buttons are disabled during the action to prevent re-entry.
    private func runAction(title: String, _ work: @escaping () throws -> Void) {
        startItem.isEnabled = false
        stopItem.isEnabled = false
        actionQueue.async { [weak self] in
            let actionError: Error?
            do {
                try work()
                actionError = nil
            } catch {
                actionError = error
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = actionError {
                    self.presentError(error, title: title)
                }
                // force: always re-publish so the buttons are re-enabled even
                // when a failed action left the loaded state unchanged.
                self.servicePoller.refresh(force: true)
            }
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
