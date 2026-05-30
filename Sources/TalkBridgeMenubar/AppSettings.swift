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
    private let bridgeRepoPathKey = "bridgeRepoPath"

    static let defaultBridgeRepoPath =
        "/Users/patrick/Documents/Aktuell/opencode-talk-bridge"

    static let serviceLabel = "com.leiverkus.opencode-talk-bridge"

    @Published var wakeMode: WakeMode {
        didSet { defaults.set(wakeMode.rawValue, forKey: wakeModeKey) }
    }
    @Published var bridgeRepoPath: String {
        didSet { defaults.set(bridgeRepoPath, forKey: bridgeRepoPathKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.wakeMode = {
            guard let raw = defaults.string(forKey: "wakeMode"),
                  let mode = WakeMode(rawValue: raw) else { return .coupled }
            return mode
        }()
        self.bridgeRepoPath = defaults.string(forKey: "bridgeRepoPath")
            ?? Self.defaultBridgeRepoPath
    }

    var bridgeRepoURL: URL { URL(fileURLWithPath: bridgeRepoPath, isDirectory: true) }

    var statusFileURL: URL {
        bridgeRepoURL.appendingPathComponent("status.json")
    }

    var venvBinaryURL: URL {
        bridgeRepoURL.appendingPathComponent(".venv/bin/opencode-talk-bridge")
    }

    var envFileURL: URL {
        bridgeRepoURL.appendingPathComponent(".env")
    }

    var plistTemplateURL: URL {
        bridgeRepoURL
            .appendingPathComponent("deploy")
            .appendingPathComponent("\(Self.serviceLabel).plist")
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
