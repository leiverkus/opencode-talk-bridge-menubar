import Foundation

/// Per-artifact result of checking whether the app can drive the bridge:
/// an executable bridge binary plus a config/working directory. The `.env`
/// is recommended (it holds credentials) but not required to wire up the
/// launchd service.
struct BridgeSetupValidation: Equatable {
    let binaryExists: Bool
    let configDirExists: Bool
    let envFileExists: Bool

    /// The config dir is created on plist install if missing, so the only
    /// hard requirement is a runnable bridge binary.
    var isUsable: Bool { binaryExists }
}

enum BridgeSetupValidator {
    static func validate(_ settings: AppSettings) -> BridgeSetupValidation {
        let fm = FileManager.default

        func isExecutableFile(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir),
                  !isDir.boolValue else { return false }
            return fm.isExecutableFile(atPath: url.path)
        }

        func isDirectory(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

        func isFile(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue
        }

        // An empty path resolves to the process CWD via fileURLWithPath(""),
        // which must not count as configured. Guard it explicitly.
        let binaryConfigured = !settings.bridgeBinaryPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty

        return BridgeSetupValidation(
            binaryExists: binaryConfigured && isExecutableFile(settings.bridgeBinaryURL),
            configDirExists: isDirectory(settings.configDirURL),
            envFileExists: isFile(settings.envFileURL)
        )
    }
}
