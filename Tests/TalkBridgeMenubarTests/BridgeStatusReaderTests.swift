import XCTest
@testable import TalkBridgeMenubar

final class BridgeStatusReaderTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-status-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testPublishesNilWhenFileMissing() {
        let reader = BridgeStatusReader(url: tempURL, pollInterval: .milliseconds(100))
        let exp = expectation(description: "first update")
        var received: BridgeStatus??
        reader.onUpdate = { status in
            received = .some(status)
            exp.fulfill()
        }
        reader.start()
        wait(for: [exp], timeout: 2)
        XCTAssertNotNil(received)
        XCTAssertNil(received!)
        reader.stop()
    }

    func testReadsExistingFileOnStart() throws {
        let json = """
        {"state":"polling","since":1,"opencode_healthy":true,
         "conversations":[],"last_error":null,"version":"0.1.1"}
        """
        try Data(json.utf8).write(to: tempURL)

        let reader = BridgeStatusReader(url: tempURL, pollInterval: .milliseconds(100))
        let exp = expectation(description: "polling")
        reader.onUpdate = { status in
            if status?.state == .polling { exp.fulfill() }
        }
        reader.start()
        wait(for: [exp], timeout: 2)
        reader.stop()
    }

    func testRetargetSwitchesToNewFile() throws {
        let oldJson = """
        {"state":"polling","since":1,"opencode_healthy":true,
         "conversations":[],"last_error":null,"version":"old"}
        """
        try Data(oldJson.utf8).write(to: tempURL)

        let secondURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bridge-status-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let newJson = """
        {"state":"working","since":2,"opencode_healthy":true,
         "conversations":[],"last_error":null,"version":"new"}
        """
        try Data(newJson.utf8).write(to: secondURL)

        let reader = BridgeStatusReader(url: tempURL, pollInterval: .milliseconds(200))
        let sawOld = expectation(description: "saw old file")
        let sawNew = expectation(description: "saw new file after retarget")

        reader.onUpdate = { status in
            switch status?.version {
            case "old": sawOld.fulfill()
            case "new": sawNew.fulfill()
            default: break
            }
        }
        reader.start()
        wait(for: [sawOld], timeout: 2)

        reader.retarget(to: secondURL)
        wait(for: [sawNew], timeout: 3)
        reader.stop()
    }

    func testPicksUpAtomicReplace() throws {
        let initial = """
        {"state":"starting","since":1,"opencode_healthy":false,
         "conversations":[],"last_error":null,"version":"0.1.1"}
        """
        try Data(initial.utf8).write(to: tempURL)

        let reader = BridgeStatusReader(url: tempURL, pollInterval: .milliseconds(200))
        let firstExp = expectation(description: "starting")
        let secondExp = expectation(description: "polling")

        reader.onUpdate = { status in
            switch status?.state {
            case .starting: firstExp.fulfill()
            case .polling:  secondExp.fulfill()
            default: break
            }
        }
        reader.start()
        wait(for: [firstExp], timeout: 2)

        // simulate atomic rename: write temp, rename over target
        let tmp = tempURL.appendingPathExtension("new")
        let updated = """
        {"state":"polling","since":2,"opencode_healthy":true,
         "conversations":[],"last_error":null,"version":"0.1.1"}
        """
        try Data(updated.utf8).write(to: tmp)
        _ = try FileManager.default.replaceItemAt(tempURL, withItemAt: tmp)

        wait(for: [secondExp], timeout: 3)
        reader.stop()
    }
}
