import SwiftUI

/// Shared green-check / red-x rows showing whether the app can drive the
/// bridge. Used by both the onboarding window and the Settings → Bridge tab.
struct BridgeSetupStatusRows: View {
    let validation: BridgeSetupValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Bridge-Binary (ausführbar)", ok: validation.binaryExists, required: true)
            row("Konfig-Ordner", ok: validation.configDirExists, required: false)
            row(".env (Credentials, empfohlen)", ok: validation.envFileExists, required: false)
        }
    }

    @ViewBuilder
    private func row(_ label: String, ok: Bool, required: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName(ok: ok, required: required))
                .foregroundColor(color(ok: ok, required: required))
            Text(label)
                .font(.callout)
            Spacer()
        }
    }

    private func symbolName(ok: Bool, required: Bool) -> String {
        if ok { return "checkmark.circle.fill" }
        return required ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private func color(ok: Bool, required: Bool) -> Color {
        if ok { return .green }
        return required ? .red : .yellow
    }
}
