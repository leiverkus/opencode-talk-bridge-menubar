import SwiftUI

/// Shared green-check / red-x rows showing whether the configured bridge repo
/// contains the artifacts the app needs. Used by both the onboarding window
/// and the Settings → Bridge tab.
struct BridgeRepoStatusRows: View {
    let validation: BridgeRepoValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Repo-Ordner", ok: validation.repoExists, required: true)
            row("plist-Vorlage (deploy/…plist)", ok: validation.plistTemplateExists, required: true)
            row("venv-Binary (.venv/bin/…)", ok: validation.venvBinaryExists, required: true)
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
