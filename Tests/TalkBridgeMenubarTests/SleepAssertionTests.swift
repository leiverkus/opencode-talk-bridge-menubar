import XCTest
import IOKit.pwr_mgt
@testable import TalkBridgeMenubar

private final class MockPowerAPI: PowerAssertionAPI {
    var createCount = 0
    var releaseCount = 0
    var nextID: IOPMAssertionID = 1
    var failCreate = false

    func create(name: String) -> IOPMAssertionID? {
        createCount += 1
        if failCreate { return nil }
        let id = nextID
        nextID += 1
        return id
    }

    func release(_ id: IOPMAssertionID) {
        releaseCount += 1
    }
}

final class SleepAssertionTests: XCTestCase {
    func testAcquireCreatesAssertionOnce() {
        let api = MockPowerAPI()
        let assertion = SleepAssertion(name: "test", api: api)

        assertion.acquire()
        assertion.acquire()
        assertion.acquire()

        XCTAssertEqual(api.createCount, 1, "Repeated acquire() must be idempotent")
        XCTAssertTrue(assertion.isActive)
    }

    func testReleaseFreesAssertion() {
        let api = MockPowerAPI()
        let assertion = SleepAssertion(name: "test", api: api)

        assertion.acquire()
        assertion.release()

        XCTAssertEqual(api.releaseCount, 1)
        XCTAssertFalse(assertion.isActive)
    }

    func testReleaseWithoutAcquireIsNoop() {
        let api = MockPowerAPI()
        let assertion = SleepAssertion(name: "test", api: api)

        assertion.release()

        XCTAssertEqual(api.releaseCount, 0)
    }

    func testReacquireAfterRelease() {
        let api = MockPowerAPI()
        let assertion = SleepAssertion(name: "test", api: api)

        assertion.acquire()
        assertion.release()
        assertion.acquire()

        XCTAssertEqual(api.createCount, 2)
        XCTAssertEqual(api.releaseCount, 1)
        XCTAssertTrue(assertion.isActive)
    }

    func testCreateFailureLeavesInactive() {
        let api = MockPowerAPI()
        api.failCreate = true
        let assertion = SleepAssertion(name: "test", api: api)

        assertion.acquire()

        XCTAssertFalse(assertion.isActive)
        XCTAssertEqual(api.releaseCount, 0)
    }

    func testDeinitReleasesActiveAssertion() {
        let api = MockPowerAPI()
        autoreleasepool {
            let assertion = SleepAssertion(name: "test", api: api)
            assertion.acquire()
            XCTAssertTrue(assertion.isActive)
        }
        XCTAssertEqual(api.releaseCount, 1)
    }
}
