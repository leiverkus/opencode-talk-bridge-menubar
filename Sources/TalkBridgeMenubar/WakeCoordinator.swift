import Foundation

/// Decides whether the IOPM assertion should be held, based on the user's
/// chosen WakeMode and whether the bridge is currently running.
/// Bridge-running input is wired up in step 5 (coupled mode).
final class WakeCoordinator {
    private let assertion: SleepAssertion
    private(set) var mode: WakeMode
    private var bridgeIsRunning: Bool = false

    init(assertion: SleepAssertion, mode: WakeMode) {
        self.assertion = assertion
        self.mode = mode
        reconcile()
    }

    func setMode(_ newMode: WakeMode) {
        mode = newMode
        reconcile()
    }

    func setBridgeRunning(_ running: Bool) {
        bridgeIsRunning = running
        reconcile()
    }

    private func reconcile() {
        let shouldHold: Bool
        switch mode {
        case .always:  shouldHold = true
        case .off:     shouldHold = false
        case .coupled: shouldHold = bridgeIsRunning
        }
        if shouldHold {
            assertion.acquire()
        } else {
            assertion.release()
        }
    }
}
