import Foundation
import Combine

enum WakeMode: String, CaseIterable, Identifiable {
    case coupled
    case always
    case off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coupled: return "Nur wenn Bridge läuft"
        case .always:  return "Immer wachhalten"
        case .off:     return "Aus"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let wakeModeKey = "wakeMode"
    private let bridgeBinaryPathKey = "bridgeBinaryPath"
    private let configDirPathKey = "configDirPath"

    static let serviceLabel = "com.leiverkus.opencode-talk-bridge"

    /// Where `uv tool install` / `pipx install opencode-talk-bridge` place the
    /// console script.
    static var defaultBinaryPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/opencode-talk-bridge").path
    }

    /// Working directory holding `.env`, `status.json`, and `bridge.sqlite3`.
    /// Matches the bridge's own example plist (XDG-style `~/.config`).
    static var defaultConfigDirPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode-talk-bridge").path
    }

    @Published var wakeMode: WakeMode {
        didSet { defaults.set(wakeMode.rawValue, forKey: wakeModeKey) }
    }
    @Published var bridgeBinaryPath: String {
        didSet { defaults.set(bridgeBinaryPath, forKey: bridgeBinaryPathKey) }
    }
    @Published var configDirPath: String {
        didSet { defaults.set(configDirPath, forKey: configDirPathKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.wakeMode = {
            guard let raw = defaults.string(forKey: "wakeMode"),
                  let mode = WakeMode(rawValue: raw) else { return .coupled }
            return mode
        }()
        // PyPI-first model: default to the uv/pipx install locations. Fresh
        // installs that don't match are caught by onboarding.
        self.bridgeBinaryPath = defaults.string(forKey: "bridgeBinaryPath")
            ?? Self.defaultBinaryPath
        self.configDirPath = defaults.string(forKey: "configDirPath")
            ?? Self.defaultConfigDirPath
    }

    private static func url(for path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    var bridgeBinaryURL: URL { Self.url(for: bridgeBinaryPath) }

    var configDirURL: URL { Self.url(for: configDirPath) }

    var envFileURL: URL {
        configDirURL.appendingPathComponent(".env")
    }

    var statusFileURL: URL {
        configDirURL.appendingPathComponent("status.json")
    }

    var installedPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(Self.serviceLabel).plist")
    }

    var stdoutLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/opencode-talk-bridge.out.log")
    }

    var stderrLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/opencode-talk-bridge.err.log")
    }
}
