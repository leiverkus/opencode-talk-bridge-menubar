import XCTest
@testable import TalkBridgeMenubar

private final class MockProbe: ServiceLoadedProbe {
    var loaded: Bool
    private(set) var callCount = 0
    init(loaded: Bool) { self.loaded = loaded }
    func isLoaded() -> Bool {
        callCount += 1
        return loaded
    }
}

final class ServiceStatePollerTests: XCTestCase {

    /// Runs the poller's internal work queue and its publish queue on the same
    /// serial queue so we can assert synchronously after a barrier sync.
    private func makePoller(probe: ServiceLoadedProbe) -> (ServiceStatePoller, DispatchQueue) {
        let q = DispatchQueue(label: "poller-test-\(UUID().uuidString)")
        let poller = ServiceStatePoller(
            service: probe,
            interval: .seconds(60),
            queue: q,
            publishQueue: q
        )
        return (poller, q)
    }

    private func drain(_ q: DispatchQueue) {
        q.sync {}
    }

    func testRefreshPublishesOnFirstCheck() {
        let probe = MockProbe(loaded: true)
        let (poller, q) = makePoller(probe: probe)
        var received: [Bool] = []
        poller.onUpdate = { received.append($0) }

        poller.refresh()
        drain(q); drain(q)

        XCTAssertEqual(received, [true])
    }

    func testRefreshDedupesUnchangedValue() {
        let probe = MockProbe(loaded: false)
        let (poller, q) = makePoller(probe: probe)
        var received: [Bool] = []
        poller.onUpdate = { received.append($0) }

        poller.refresh()        // publishes false
        drain(q); drain(q)
        poller.refresh()        // unchanged → swallowed
        drain(q); drain(q)

        XCTAssertEqual(received, [false])
    }

    func testForcedRefreshAlwaysPublishesEvenWhenUnchanged() {
        // This is the regression guard: a failed Start leaves loaded == false,
        // and the menu must still get an update to re-enable its buttons.
        let probe = MockProbe(loaded: false)
        let (poller, q) = makePoller(probe: probe)
        var received: [Bool] = []
        poller.onUpdate = { received.append($0) }

        poller.refresh()              // publishes false
        drain(q); drain(q)
        poller.refresh(force: true)   // same value, but forced
        drain(q); drain(q)
        poller.refresh(force: true)   // and again
        drain(q); drain(q)

        XCTAssertEqual(received, [false, false, false])
    }

    func testPublishesChangeWhenValueFlips() {
        let probe = MockProbe(loaded: false)
        let (poller, q) = makePoller(probe: probe)
        var received: [Bool] = []
        poller.onUpdate = { received.append($0) }

        poller.refresh()
        drain(q); drain(q)
        probe.loaded = true
        poller.refresh()
        drain(q); drain(q)

        XCTAssertEqual(received, [false, true])
    }
}
