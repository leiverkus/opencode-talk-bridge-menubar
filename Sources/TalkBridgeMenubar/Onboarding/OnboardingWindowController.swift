import AppKit
import SwiftUI

/// Owns the first-run onboarding NSWindow. Mirrors SettingsWindowController:
/// lazily created, reused, and brought to front (the app is an LSUIElement
/// agent, so it must activate itself to surface a window).
final class OnboardingWindowController {
    private var window: NSWindow?
    private let settings: AppSettings
    private let bridgeService: BridgeService

    init(settings: AppSettings, bridgeService: BridgeService) {
        self.settings = settings
        self.bridgeService = bridgeService
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func showWindow() {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let root = OnboardingView(
            settings: settings,
            bridgeService: bridgeService,
            onFinish: { [weak self] in self?.close() }
        )
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)
        win.title = "Talk Bridge — Einrichtung"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
    }
}
