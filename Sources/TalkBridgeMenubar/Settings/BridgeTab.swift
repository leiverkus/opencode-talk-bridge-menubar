import SwiftUI
import AppKit

struct BridgeTab: View {
    @ObservedObject var settings: AppSettings
    let bridgeService: BridgeService
    var onServiceChanged: () -> Void = {}

    @State private var lastActionMessage: String?
    @State private var lastActionWasError = false

    var body: some View {
        Form {
            Section("Bridge") {
                HStack {
                    TextField("Bridge-Binary", text: $settings.bridgeBinaryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Datei…", action: pickBinary)
                }
                HStack {
                    TextField("Konfig-Ordner", text: $settings.configDirPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Ordner…", action: pickConfigDir)
                }
                BridgeSetupStatusRows(
                    validation: BridgeSetupValidator.validate(settings)
                )
                LabeledContent(".env", value: settings.envFileURL.path)
                    .font(.callout.monospaced())
                LabeledContent("Status-File", value: settings.statusFileURL.path)
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
                Button("Dienst entfernen…", role: .destructive,
                       action: confirmUninstall)
            }

            if let msg = lastActionMessage {
                Text(msg)
                    .foregroundColor(lastActionWasError ? .red : .secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
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

    private func installPlist() {
        do {
            try bridgeService.installPlist()
            lastActionWasError = false
            lastActionMessage = "plist installiert: \(settings.installedPlistURL.path)"
        } catch {
            lastActionWasError = true
            lastActionMessage = String(describing: error)
        }
        onServiceChanged()
    }

    private func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "Dienst entfernen?"
        alert.informativeText = "Stoppt den launchd-Dienst (bootout) und löscht die installierte plist unter \(settings.installedPlistURL.path). Bridge-Binary, Konfig-Ordner und .env bleiben unangetastet."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Entfernen")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        uninstall()
    }

    private func uninstall() {
        do {
            try bridgeService.uninstallPlist()
            lastActionWasError = false
            lastActionMessage = "Dienst entfernt und plist gelöscht."
        } catch {
            lastActionWasError = true
            lastActionMessage = String(describing: error)
        }
        onServiceChanged()
    }

    private func openEnv() {
        let fm = FileManager.default
        try? fm.createDirectory(at: settings.configDirURL, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: settings.envFileURL.path) {
            fm.createFile(atPath: settings.envFileURL.path, contents: Data())
        }
        NSWorkspace.shared.open(settings.envFileURL)
    }
}
