import AppKit
import SwiftUI

/// Owns the Settings NSWindow. The window is created lazily on first open
/// and reused on subsequent opens.
final class SettingsWindowController {
    private weak var window: NSWindow?
    private let settings: AppSettings
    private let bridgeService: BridgeService
    private let currentStatus: () -> BridgeStatus?
    private let onServiceChanged: () -> Void

    init(settings: AppSettings,
         bridgeService: BridgeService,
         currentStatus: @escaping () -> BridgeStatus?,
         onServiceChanged: @escaping () -> Void) {
        self.settings = settings
        self.bridgeService = bridgeService
        self.currentStatus = currentStatus
        self.onServiceChanged = onServiceChanged
    }

    func showWindow() {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let root = SettingsView(
            settings: settings,
            bridgeService: bridgeService,
            currentStatus: currentStatus,
            onServiceChanged: onServiceChanged
        )
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)
        win.title = "Talk Bridge — Einstellungen"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
