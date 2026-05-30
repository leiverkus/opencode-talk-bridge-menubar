import SwiftUI
import AppKit

struct GeneralTab: View {
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginStatus = LoginItem.statusDescription
    @State private var lastError: String?

    private let settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Beim Login starten") {
                Toggle("App beim Login automatisch starten",
                       isOn: Binding(
                        get: { loginEnabled },
                        set: { toggle(to: $0) }
                       ))
                LabeledContent("Status", value: loginStatus)
                    .font(.callout)
                if let err = lastError {
                    Text(err).foregroundColor(.red).font(.callout)
                }
            }

            Section("Bridge-Logs") {
                HStack {
                    Button("stdout öffnen") {
                        NSWorkspace.shared.open(settings.stdoutLogURL)
                    }
                    Button("stderr öffnen") {
                        NSWorkspace.shared.open(settings.stderrLogURL)
                    }
                }
                LabeledContent("stdout", value: settings.stdoutLogURL.path)
                    .font(.callout.monospaced())
                LabeledContent("stderr", value: settings.stderrLogURL.path)
                    .font(.callout.monospaced())
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
    }

    private func toggle(to enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
        refresh()
    }

    private func refresh() {
        loginEnabled = LoginItem.isEnabled
        loginStatus = LoginItem.statusDescription
    }
}
