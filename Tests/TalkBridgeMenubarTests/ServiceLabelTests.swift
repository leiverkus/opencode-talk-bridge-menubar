import XCTest
import Darwin
@testable import TalkBridgeMenubar

final class ServiceLabelTests: XCTestCase {
    func testServiceTargetIncludesUidAndLabel() {
        let target = BridgeService.serviceTarget(label: AppSettings.serviceLabel)
        XCTAssertEqual(target, "gui/\(getuid())/com.leiverkus.opencode-talk-bridge")
    }

    func testCanonicalLabelMatchesBridgeRepo() {
        // Hard-coded sanity check: must match the Label in the bridge's
        // deploy/com.leiverkus.opencode-talk-bridge.plist.
        XCTAssertEqual(AppSettings.serviceLabel, "com.leiverkus.opencode-talk-bridge")
    }
}
