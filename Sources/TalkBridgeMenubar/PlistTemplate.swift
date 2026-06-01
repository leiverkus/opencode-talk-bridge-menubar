import Foundation

enum PlistTemplate {
    struct Substitutions {
        let binary: URL
        let envFile: URL
        let workingDirectory: URL
        let stdoutLog: URL
        let stderrLog: URL
    }

    /// Builds the launchd user-agent plist for the bridge from scratch.
    ///
    /// The bridge is now installed from PyPI (`uv tool install` / `pipx`), so
    /// it no longer ships a `deploy/…plist` we could read — the app owns the
    /// canonical template here. Mirrors the bridge repo's example plist:
    /// restart on crash but not on clean exit, throttle restarts, run in the
    /// background.
    static func generate(label: String = AppSettings.serviceLabel,
                         with subs: Substitutions) -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                subs.binary.path,
                "--env-file",
                subs.envFile.path
            ],
            "WorkingDirectory": subs.workingDirectory.path,
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 10,
            "StandardOutPath": subs.stdoutLog.path,
            "StandardErrorPath": subs.stderrLog.path,
            "ProcessType": "Background"
        ]
        // PropertyListSerialization with a fixed-shape, type-safe dict cannot
        // fail; fall back to empty data rather than forcing the call to throw.
        return (try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )) ?? Data()
    }
}
