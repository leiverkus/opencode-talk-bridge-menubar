import SwiftUI
import AppKit

struct BridgeTab: View {
    @ObservedObject var settings: AppSettings
    let bridgeService: BridgeService

    @State private var lastActionMessage: String?
    @State private var lastActionWasError = false

    var body: some View {
        Form {
            Section("Bridge-Repo") {
                HStack {
                    TextField("Pfad", text: $settings.bridgeRepoPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Auswählen…", action: pickRepo)
                }
                BridgeRepoStatusRows(
                    validation: BridgeRepoValidator.validate(settings)
                )
                LabeledContent("venv-Binary",
                               value: settings.venvBinaryURL.path)
                    .font(.callout.monospaced())
                LabeledContent(".env",
                               value: settings.envFileURL.path)
                    .font(.callout.monospaced())
                LabeledContent("Status-File",
                               value: settings.statusFileURL.path)
                    .font(.callout.monospaced())
                LabeledContent("plist-Vorlage",
                               value: settings.plistTemplateURL.path)
                    .font(.callout.monospaced())
            }

            Section("launchd-Service") {
                LabeledContent("Label", value: AppSettings.serviceLabel)
                    .font(.callout.monospaced())
                LabeledContent("Installierte plist",
                               value: settings.installedPlistURL.path)
                    .font(.callout.monospaced())
                HStack {
                    Button("plist installieren / aktualisieren",
                           action: installPlist)
                    Button(".env öffnen", action: openEnv)
                }
            }

            if let msg = lastActionMessage {
                Text(msg)
                    .foregroundColor(lastActionWasError ? .red : .secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
    }

    private func pickRepo() {
        if let url = FolderPicker.pickDirectory(startingAt: settings.bridgeRepoURL) {
            settings.bridgeRepoPath = url.path
        }
    }

    private func installPlist() {
        do {
            try bridgeService.installPlist()
            lastActionWasError = false
            lastActionMessage = "plist installiert: \(settings.installedPlistURL.path)"
        } catch {
            lastActionWasError = true
            lastActionMessage = String(describing: error)
        }
    }

    private func openEnv() {
        NSWorkspace.shared.open(settings.envFileURL)
    }
}
