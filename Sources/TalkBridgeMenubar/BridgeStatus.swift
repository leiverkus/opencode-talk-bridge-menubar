import Foundation

enum BridgeState: String, Codable, CaseIterable {
    case starting
    case polling
    case working
    case opencodeDown = "opencode_down"
    case error
    case stopped
}

struct BridgeStatus: Codable, Equatable {
    let state: BridgeState
    let since: Int
    let opencodeHealthy: Bool
    let conversations: [String]
    let lastError: String?
    let version: String

    enum CodingKeys: String, CodingKey {
        case state
        case since
        case opencodeHealthy = "opencode_healthy"
        case conversations
        case lastError = "last_error"
        case version
    }

    /// True while the bridge is actively running (not stopped, not in error).
    var isLive: Bool {
        switch state {
        case .starting, .polling, .working: return true
        case .opencodeDown, .error, .stopped: return false
        }
    }
}
