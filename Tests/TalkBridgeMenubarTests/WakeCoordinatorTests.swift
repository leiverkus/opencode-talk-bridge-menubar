import XCTest
import IOKit.pwr_mgt
@testable import TalkBridgeMenubar

private final class CountingPowerAPI: PowerAssertionAPI {
    var active = 0
    var nextID: IOPMAssertionID = 1

    func create(name: String) -> IOPMAssertionID? {
        active += 1
        let id = nextID
        nextID += 1
        return id
    }
    func release(_ id: IOPMAssertionID) {
        active -= 1
    }
}

final class WakeCoordinatorTests: XCTestCase {
    func testAlwaysHoldsAssertionImmediately() {
        let api = CountingPowerAPI()
        let assertion = SleepAssertion(api: api)
        _ = WakeCoordinator(assertion: assertion, mode: .always)
        XCTAssertEqual(api.active, 1)
    }

    func testOffNeverHolds() {
        let api = CountingPowerAPI()
        let assertion = SleepAssertion(api: api)
        let wc = WakeCoordinator(assertion: assertion, mode: .off)
        wc.setBridgeRunning(true)
        XCTAssertEqual(api.active, 0)
    }

    func testCoupledFollowsBridgeState() {
        let api = CountingPowerAPI()
        let assertion = SleepAssertion(api: api)
        let wc = WakeCoordinator(assertion: assertion, mode: .coupled)

        XCTAssertEqual(api.active, 0)
        wc.setBridgeRunning(true)
        XCTAssertEqual(api.active, 1)
        wc.setBridgeRunning(false)
        XCTAssertEqual(api.active, 0)
    }

    func testModeSwitchReconciles() {
        let api = CountingPowerAPI()
        let assertion = SleepAssertion(api: api)
        let wc = WakeCoordinator(assertion: assertion, mode: .always)
        XCTAssertEqual(api.active, 1)

        wc.setMode(.off)
        XCTAssertEqual(api.active, 0)

        wc.setMode(.always)
        XCTAssertEqual(api.active, 1)
    }
}
