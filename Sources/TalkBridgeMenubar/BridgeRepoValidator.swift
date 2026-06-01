import Foundation

/// Per-artifact result of checking whether a configured bridge repo path
/// actually points at a usable opencode-talk-bridge checkout.
struct BridgeRepoValidation: Equatable {
    let repoExists: Bool
    let plistTemplateExists: Bool
    let venvBinaryExists: Bool
    let envFileExists: Bool

    /// The app can install the plist and drive launchctl once these three
    /// are present. The `.env` is recommended (it holds credentials) but not
    /// required to wire up the launchd service, so it is excluded here.
    var isUsable: Bool {
        repoExists && plistTemplateExists && venvBinaryExists
    }
}

enum BridgeRepoValidator {
    static func validate(_ settings: AppSettings) -> BridgeRepoValidation {
        let fm = FileManager.default

        func isDirectory(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

        func isFile(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
        }

        // An empty path resolves to the process CWD via fileURLWithPath(""),
        // which must not count as a valid repo. Guard it explicitly.
        let pathConfigured = !settings.bridgeRepoPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty

        guard pathConfigured else {
            return BridgeRepoValidation(
                repoExists: false,
                plistTemplateExists: false,
                venvBinaryExists: false,
                envFileExists: false
            )
        }

        return BridgeRepoValidation(
            repoExists: isDirectory(settings.bridgeRepoURL),
            plistTemplateExists: isFile(settings.plistTemplateURL),
            venvBinaryExists: isFile(settings.venvBinaryURL),
            envFileExists: isFile(settings.envFileURL)
        )
    }
}
