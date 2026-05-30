import Foundation
import IOKit
import IOKit.pwr_mgt

protocol PowerAssertionAPI {
    func create(name: String) -> IOPMAssertionID?
    func release(_ id: IOPMAssertionID)
}

struct SystemPowerAssertionAPI: PowerAssertionAPI {
    func create(name: String) -> IOPMAssertionID? {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }

    func release(_ id: IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }
}

/// RAII wrapper around an IOPMAssertion.
/// Idempotent: multiple acquire() calls hold a single assertion;
/// release() and deinit always free it.
final class SleepAssertion {
    private let api: PowerAssertionAPI
    private let name: String
    private var assertionID: IOPMAssertionID?

    var isActive: Bool { assertionID != nil }

    init(name: String = "TalkBridgeMenubar — keep awake while bridge runs",
         api: PowerAssertionAPI = SystemPowerAssertionAPI()) {
        self.name = name
        self.api = api
    }

    func acquire() {
        guard assertionID == nil else { return }
        assertionID = api.create(name: name)
    }

    func release() {
        guard let id = assertionID else { return }
        api.release(id)
        assertionID = nil
    }

    deinit {
        release()
    }
}
