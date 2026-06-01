import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    let bridgeService: BridgeService
    var onFinish: () -> Void

    @State private var installMessage: String?
    @State private var installWasError = false

    private var validation: BridgeSetupValidation {
        BridgeSetupValidator.validate(settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Willkommen bei Talk Bridge")
                    .font(.title2.bold())
                Text("Installiere die Bridge per `uv tool install opencode-talk-bridge` (oder `pipx install opencode-talk-bridge`). Bestätige dann unten den Pfad zum Binary und den Konfig-Ordner für `.env` / `status.json`.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Pfad zum Bridge-Binary", text: $settings.bridgeBinaryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Datei wählen…", action: pickBinary)
                }
                HStack {
                    TextField("Konfig-Ordner", text: $settings.configDirPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Ordner wählen…", action: pickConfigDir)
                }
            }

            BridgeSetupStatusRows(validation: validation)

            Divider()

            HStack(spacing: 12) {
                Button("Konfig-Ordner anlegen", action: createConfigDir)
                    .disabled(validation.configDirExists)
                Button("plist installieren", action: installPlist)
                    .disabled(!validation.isUsable)
                Button(".env öffnen", action: openEnv)
            }

            if let msg = installMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundColor(installWasError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !validation.envFileExists {
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
        .frame(width: 540, height: 420)
    }

    private func pickBinary() {
        if let url = PathPicker.pickFile(startingAt: settings.bridgeBinaryURL) {
            settings.bridgeBinaryPath = url.path
        }
    }

    private func pickConfigDir() {
        if let url = PathPicker.pickDirectory(startingAt: settings.configDirURL) {
            settings.configDirPath = url.path
        }
    }

    private func createConfigDir() {
        do {
            try FileManager.default.createDirectory(
                at: settings.configDirURL, withIntermediateDirectories: true
            )
            installWasError = false
            installMessage = "Konfig-Ordner angelegt: \(settings.configDirURL.path)"
        } catch {
            installWasError = true
            installMessage = String(describing: error)
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
        // Create config dir + an empty .env if missing so the editor opens
        // something rather than failing.
        let fm = FileManager.default
        try? fm.createDirectory(at: settings.configDirURL, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: settings.envFileURL.path) {
            fm.createFile(atPath: settings.envFileURL.path, contents: Data())
        }
        NSWorkspace.shared.open(settings.envFileURL)
    }
}
