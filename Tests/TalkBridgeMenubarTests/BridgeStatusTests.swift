import XCTest
@testable import TalkBridgeMenubar

final class BridgeStatusTests: XCTestCase {
    private func decode(_ json: String) throws -> BridgeStatus {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(BridgeStatus.self, from: data)
    }

    func testDecodesPollingStateWithNullError() throws {
        let json = """
        {
          "state": "polling",
          "since": 1748600000,
          "opencode_healthy": true,
          "conversations": ["abcdef12"],
          "last_error": null,
          "version": "0.1.1"
        }
        """
        let s = try decode(json)
        XCTAssertEqual(s.state, .polling)
        XCTAssertEqual(s.since, 1748600000)
        XCTAssertTrue(s.opencodeHealthy)
        XCTAssertEqual(s.conversations, ["abcdef12"])
        XCTAssertNil(s.lastError)
        XCTAssertEqual(s.version, "0.1.1")
        XCTAssertTrue(s.isLive)
    }

    func testDecodesAllStateValues() throws {
        let cases: [(String, BridgeState)] = [
            ("starting", .starting),
            ("polling", .polling),
            ("working", .working),
            ("opencode_down", .opencodeDown),
            ("error", .error),
            ("stopped", .stopped),
        ]
        for (raw, expected) in cases {
            let json = """
            { "state": "\(raw)", "since": 0, "opencode_healthy": false,
              "conversations": [], "last_error": "x", "version": "0" }
            """
            let s = try decode(json)
            XCTAssertEqual(s.state, expected, "for raw=\(raw)")
        }
    }

    func testDecodesErrorStateWithMessage() throws {
        let json = """
        { "state": "error", "since": 1, "opencode_healthy": false,
          "conversations": [], "last_error": "config missing NC_URL",
          "version": "0.1.1" }
        """
        let s = try decode(json)
        XCTAssertEqual(s.state, .error)
        XCTAssertEqual(s.lastError, "config missing NC_URL")
        XCTAssertFalse(s.isLive)
    }

    func testStoppedIsNotLive() throws {
        let json = """
        { "state": "stopped", "since": 1, "opencode_healthy": false,
          "conversations": [], "last_error": null, "version": "0.1.1" }
        """
        XCTAssertFalse(try decode(json).isLive)
    }

    func testOpencodeDownIsNotLiveForWakeCoupling() throws {
        let json = """
        { "state": "opencode_down", "since": 1, "opencode_healthy": false,
          "conversations": [], "last_error": "connection refused",
          "version": "0.1.1" }
        """
        // wake coupling releases the assertion when the bridge is parked.
        XCTAssertFalse(try decode(json).isLive)
    }

    func testRejectsUnknownState() {
        let json = """
        { "state": "spinning", "since": 1, "opencode_healthy": false,
          "conversations": [], "last_error": null, "version": "0.1.1" }
        """
        XCTAssertThrowsError(try decode(json))
    }
}
