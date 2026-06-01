import XCTest
@testable import TalkBridgeMenubar

final class PlistTemplateTests: XCTestCase {

    private func subs() -> PlistTemplate.Substitutions {
        PlistTemplate.Substitutions(
            binary: URL(fileURLWithPath: "/Users/me/.local/bin/opencode-talk-bridge"),
            envFile: URL(fileURLWithPath: "/Users/me/.config/opencode-talk-bridge/.env"),
            workingDirectory: URL(fileURLWithPath: "/Users/me/.config/opencode-talk-bridge"),
            stdoutLog: URL(fileURLWithPath: "/Users/me/Library/Logs/opencode-talk-bridge.out.log"),
            stderrLog: URL(fileURLWithPath: "/Users/me/Library/Logs/opencode-talk-bridge.err.log")
        )
    }

    private func reparse(_ data: Data) throws -> [String: Any] {
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        let raw = try PropertyListSerialization.propertyList(
            from: data, options: [], format: &fmt)
        return raw as! [String: Any]
    }

    func testGeneratesProgramArguments() throws {
        let data = PlistTemplate.generate(label: "com.example.svc", with: subs())
        let plist = try reparse(data)
        let args = plist["ProgramArguments"] as! [String]
        XCTAssertEqual(args, [
            "/Users/me/.local/bin/opencode-talk-bridge",
            "--env-file",
            "/Users/me/.config/opencode-talk-bridge/.env"
        ])
    }

    func testGeneratesWorkingDirAndLogPaths() throws {
        let plist = try reparse(PlistTemplate.generate(with: subs()))
        XCTAssertEqual(plist["WorkingDirectory"] as? String,
                       "/Users/me/.config/opencode-talk-bridge")
        XCTAssertEqual(plist["StandardOutPath"] as? String,
                       "/Users/me/Library/Logs/opencode-talk-bridge.out.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String,
                       "/Users/me/Library/Logs/opencode-talk-bridge.err.log")
    }

    func testUsesProvidedLabel() throws {
        let plist = try reparse(
            PlistTemplate.generate(label: "com.example.svc", with: subs()))
        XCTAssertEqual(plist["Label"] as? String, "com.example.svc")
    }

    func testDefaultLabelIsServiceLabel() throws {
        let plist = try reparse(PlistTemplate.generate(with: subs()))
        XCTAssertEqual(plist["Label"] as? String, AppSettings.serviceLabel)
    }

    func testKeepAliveAndThrottleAndProcessType() throws {
        let plist = try reparse(PlistTemplate.generate(with: subs()))
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["ThrottleInterval"] as? Int, 10)
        XCTAssertEqual(plist["ProcessType"] as? String, "Background")
        let keepAlive = plist["KeepAlive"] as! [String: Any]
        XCTAssertEqual(keepAlive["SuccessfulExit"] as? Bool, false)
    }

    func testGeneratedPlistIsValidXML() {
        let data = PlistTemplate.generate(with: subs())
        XCTAssertFalse(data.isEmpty)
        XCTAssertNoThrow(try reparse(data))
    }
}
