import XCTest
@testable import TalkBridgeMenubar

final class PlistTemplateTests: XCTestCase {

    private let template = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.leiverkus.opencode-talk-bridge</string>
        <key>ProgramArguments</key>
        <array>
            <string>/old/path/.venv/bin/opencode-talk-bridge</string>
            <string>--env-file</string>
            <string>/old/path/.env</string>
        </array>
        <key>WorkingDirectory</key>
        <string>/old/path</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <dict>
            <key>SuccessfulExit</key>
            <false/>
        </dict>
        <key>ThrottleInterval</key>
        <integer>10</integer>
        <key>StandardOutPath</key>
        <string>/old/out.log</string>
        <key>StandardErrorPath</key>
        <string>/old/err.log</string>
        <key>ProcessType</key>
        <string>Background</string>
    </dict>
    </plist>
    """#

    private func subs() -> PlistTemplate.Substitutions {
        PlistTemplate.Substitutions(
            venvBinary: URL(fileURLWithPath: "/new/bridge/.venv/bin/opencode-talk-bridge"),
            envFile: URL(fileURLWithPath: "/new/bridge/.env"),
            workingDirectory: URL(fileURLWithPath: "/new/bridge"),
            stdoutLog: URL(fileURLWithPath: "/Users/patrick/Library/Logs/opencode-talk-bridge.out.log"),
            stderrLog: URL(fileURLWithPath: "/Users/patrick/Library/Logs/opencode-talk-bridge.err.log")
        )
    }

    private func reparse(_ data: Data) throws -> [String: Any] {
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        let raw = try PropertyListSerialization.propertyList(
            from: data, options: [], format: &fmt
        )
        return raw as! [String: Any]
    }

    func testProgramArgumentsAreRewritten() throws {
        let data = Data(template.utf8)
        let out = try PlistTemplate.rewrite(template: data, with: subs())
        let plist = try reparse(out)
        let args = plist["ProgramArguments"] as! [String]
        XCTAssertEqual(args, [
            "/new/bridge/.venv/bin/opencode-talk-bridge",
            "--env-file",
            "/new/bridge/.env"
        ])
    }

    func testWorkingDirectoryAndLogPathsAreRewritten() throws {
        let data = Data(template.utf8)
        let out = try PlistTemplate.rewrite(template: data, with: subs())
        let plist = try reparse(out)
        XCTAssertEqual(plist["WorkingDirectory"] as? String, "/new/bridge")
        XCTAssertEqual(plist["StandardOutPath"] as? String,
                       "/Users/patrick/Library/Logs/opencode-talk-bridge.out.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String,
                       "/Users/patrick/Library/Logs/opencode-talk-bridge.err.log")
    }

    func testNonPathKeysArePreserved() throws {
        let data = Data(template.utf8)
        let out = try PlistTemplate.rewrite(template: data, with: subs())
        let plist = try reparse(out)
        XCTAssertEqual(plist["Label"] as? String, "com.leiverkus.opencode-talk-bridge")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["ThrottleInterval"] as? Int, 10)
        XCTAssertEqual(plist["ProcessType"] as? String, "Background")
        let keepAlive = plist["KeepAlive"] as! [String: Any]
        XCTAssertEqual(keepAlive["SuccessfulExit"] as? Bool, false)
    }

    func testRejectsNonDictRoot() {
        let bogus = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><array><string>x</string></array></plist>
        """#
        XCTAssertThrowsError(
            try PlistTemplate.rewrite(template: Data(bogus.utf8), with: subs())
        ) { error in
            XCTAssertEqual(error as? PlistTemplate.RewriteError, .notADictionary)
        }
    }
}
