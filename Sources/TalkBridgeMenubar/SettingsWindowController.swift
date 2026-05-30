import AppKit
import SwiftUI

/// Owns the Settings NSWindow. The window is created lazily on first open
/// and reused on subsequent opens.
final class SettingsWindowController {
    private weak var window: NSWindow?
    private let settings: AppSettings
    private let bridgeService: BridgeService
    private let currentStatus: () -> BridgeStatus?

    init(settings: AppSettings,
         bridgeService: BridgeService,
         currentStatus: @escaping () -> BridgeStatus?) {
        self.settings = settings
        self.bridgeService = bridgeService
        self.currentStatus = currentStatus
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
            currentStatus: currentStatus
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
