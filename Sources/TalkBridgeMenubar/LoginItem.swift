import Foundation
import ServiceManagement

enum LoginItem {
    /// Wraps SMAppService.mainApp.status into a simple bool. Returns false on
    /// non-success states (notRegistered, requiresApproval, notFound).
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered:    return "nicht registriert"
        case .enabled:          return "aktiv"
        case .requiresApproval: return "Genehmigung erforderlich (Systemeinstellungen)"
        case .notFound:         return "nicht gefunden"
        @unknown default:       return "unbekannt"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
