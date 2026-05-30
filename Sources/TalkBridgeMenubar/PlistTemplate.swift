import Foundation

enum PlistTemplate {
    struct Substitutions {
        let venvBinary: URL
        let envFile: URL
        let workingDirectory: URL
        let stdoutLog: URL
        let stderrLog: URL
    }

    enum RewriteError: Error, Equatable {
        case notADictionary
    }

    /// Reads the bridge's plist template and substitutes the four absolute
    /// paths that vary per user / install location, leaving Label, KeepAlive,
    /// ThrottleInterval, ProcessType, RunAtLoad untouched.
    static func rewrite(template: Data, with subs: Substitutions) throws -> Data {
        var format = PropertyListSerialization.PropertyListFormat.xml
        let raw = try PropertyListSerialization.propertyList(
            from: template, options: [], format: &format
        )
        guard var plist = raw as? [String: Any] else {
            throw RewriteError.notADictionary
        }
        plist["ProgramArguments"] = [
            subs.venvBinary.path,
            "--env-file",
            subs.envFile.path
        ] as [String]
        plist["WorkingDirectory"] = subs.workingDirectory.path
        plist["StandardOutPath"] = subs.stdoutLog.path
        plist["StandardErrorPath"] = subs.stderrLog.path
        return try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
    }
}
