import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    let bridgeService: BridgeService
    var onFinish: () -> Void

    @State private var installMessage: String?
    @State private var installWasError = false

    private var validation: BridgeRepoValidation {
        BridgeRepoValidator.validate(settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Willkommen bei Talk Bridge")
                    .font(.title2.bold())
                Text("Die App steuert die Python-Bridge „opencode-talk-bridge“ als launchd-Dienst. Wähle den Ordner des Bridge-Repos — er muss `.venv/bin/opencode-talk-bridge` und `deploy/\(AppSettings.serviceLabel).plist` enthalten.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                TextField("Pfad zum Bridge-Repo", text: $settings.bridgeRepoPath)
                    .textFieldStyle(.roundedBorder)
                Button("Ordner wählen…", action: pickRepo)
            }

            BridgeRepoStatusRows(validation: validation)

            Divider()

            HStack(spacing: 12) {
                Button("plist installieren", action: installPlist)
                    .disabled(!validation.isUsable)
                Button(".env öffnen", action: openEnv)
                    .disabled(!validation.repoExists)
            }

            if let msg = installMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundColor(installWasError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !validation.envFileExists && validation.repoExists {
                Text("Hinweis: Keine `.env` gefunden. Credentials (Nextcloud, OpenCode) gehören dort hinein — die App verwaltet sie nicht.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Schließen", action: onFinish)
                Button("Fertig", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!validation.isUsable)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
    }

    private func pickRepo() {
        if let url = FolderPicker.pickDirectory(startingAt: settings.bridgeRepoURL) {
            settings.bridgeRepoPath = url.path
        }
    }

    private func installPlist() {
        do {
            try bridgeService.installPlist()
            installWasError = false
            installMessage = "plist installiert: \(settings.installedPlistURL.path)"
        } catch {
            installWasError = true
            installMessage = String(describing: error)
        }
    }

    private func openEnv() {
        NSWorkspace.shared.open(settings.envFileURL)
    }
}
