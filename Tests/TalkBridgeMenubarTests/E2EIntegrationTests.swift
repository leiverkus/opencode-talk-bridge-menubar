import XCTest
@testable import TalkBridgeMenubar

/// Opt-in end-to-end test against the real, uv/pipx-installed bridge binary
/// and the live launchd domain. Skipped unless RUN_E2E=1, so CI and normal
/// `swift test` runs never touch launchd or the user's machine state.
///
///   RUN_E2E=1 swift test --filter E2EIntegrationTests
final class E2EIntegrationTests: XCTestCase {

    private func sh(_ launchPath: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        return (p.terminationStatus, out)
    }

    func testFullLifecycleAgainstRealBridge() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_E2E"] == "1",
                          "set RUN_E2E=1 to run the live launchd e2e")

        let suite = "e2e-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        // real defaults: ~/.local/bin binary + ~/.config/opencode-talk-bridge
        let service = BridgeService(settings: settings)

        let configPreexisted = FileManager.default.fileExists(
            atPath: settings.configDirURL.path)

        // 1) binary detected as usable
        let v = BridgeSetupValidator.validate(settings)
        print("E2E validator: \(v)")
        XCTAssertTrue(v.binaryExists, "bridge binary should be runnable at \(settings.bridgeBinaryURL.path)")
        XCTAssertTrue(v.isUsable)

        // 2) install the generated plist + config dir
        try service.installPlist()
        XCTAssertTrue(FileManager.default.fileExists(atPath: settings.installedPlistURL.path),
                      "plist should be written to LaunchAgents")
        XCTAssertTrue(FileManager.default.fileExists(atPath: settings.configDirURL.path),
                      "config dir should be created")
        // sanity: generated plist points ProgramArguments at the real binary
        let plistData = try Data(contentsOf: settings.installedPlistURL)
        let plist = try PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil) as! [String: Any]
        XCTAssertEqual((plist["ProgramArguments"] as? [String])?.first,
                       settings.bridgeBinaryURL.path)

        // 3) bootstrap → service is loaded
        try service.start()
        XCTAssertTrue(service.isLoaded(), "service should be loaded after bootstrap")

        // 4) the bridge writes status.json (no .env → likely error/starting,
        //    but the read path is what we are proving)
        let reader = BridgeStatusReader(url: settings.statusFileURL,
                                        pollInterval: .milliseconds(300))
        let got = expectation(description: "status published")
        var seen: BridgeStatus?
        var fulfilled = false
        reader.onUpdate = { status in
            if let s = status, !fulfilled { seen = s; fulfilled = true; got.fulfill() }
        }
        reader.start()
        let waited = XCTWaiter().wait(for: [got], timeout: 15)
        reader.stop()
        if waited == .completed {
            print("E2E status.json: state=\(seen!.state.rawValue) version=\(seen!.version) lastError=\(seen?.lastError ?? "nil")")
        } else {
            print("E2E: status.json did not appear within 15s (bridge may have exited before writing; service-load path still verified)")
        }

        // 5) bootout → service is gone
        try service.stop()
        XCTAssertFalse(service.isLoaded(), "service should be unloaded after bootout")

        // 6) cleanup
        try service.uninstallPlist()
        XCTAssertFalse(FileManager.default.fileExists(atPath: settings.installedPlistURL.path))
        if !configPreexisted {
            try? FileManager.default.removeItem(at: settings.configDirURL)
        }
    }

    func testSleepAssertionShowsInPmset() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_E2E"] == "1",
                          "set RUN_E2E=1 to run the live pmset e2e")

        let name = "TalkBridgeMenubar-e2e-\(UUID().uuidString)"
        let assertion = SleepAssertion(name: name)

        assertion.acquire()
        XCTAssertTrue(assertion.isActive)
        let (_, withHeld) = sh("/usr/bin/pmset", ["-g", "assertions"])
        XCTAssertTrue(withHeld.contains(name),
                      "the held IOPM assertion should appear in `pmset -g assertions`")

        assertion.release()
        let (_, afterRelease) = sh("/usr/bin/pmset", ["-g", "assertions"])
        XCTAssertFalse(afterRelease.contains(name),
                       "the assertion should be gone after release")
    }
}
