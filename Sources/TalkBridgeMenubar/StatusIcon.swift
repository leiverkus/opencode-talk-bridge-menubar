import AppKit

enum StatusIcon {
    struct Spec {
        let symbolName: String
        let tooltip: String
    }

    static func spec(for status: BridgeStatus?) -> Spec {
        guard let status = status else {
            return Spec(symbolName: "circle",
                        tooltip: "Talk Bridge — kein Status (Service nicht geladen?)")
        }
        let symbol: String
        let label: String
        switch status.state {
        case .starting:
            symbol = "circle.dotted";                  label = "startet"
        case .polling:
            symbol = "dot.radiowaves.left.and.right"; label = "läuft & pollt"
        case .working:
            symbol = "gearshape.2";                    label = "arbeitet"
        case .opencodeDown:
            symbol = "xmark.icloud";                   label = "OpenCode nicht erreichbar"
        case .error:
            symbol = "exclamationmark.triangle.fill"; label = "Fehler"
        case .stopped:
            symbol = "pause.circle";                   label = "gestoppt"
        }
        var tooltip = "Talk Bridge — \(label) (v\(status.version))"
        if let err = status.lastError, !err.isEmpty {
            tooltip += "\n\(err)"
        }
        return Spec(symbolName: symbol, tooltip: tooltip)
    }

    static func image(for spec: Spec) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(
            systemSymbolName: spec.symbolName,
            accessibilityDescription: spec.tooltip
        )?.withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}
