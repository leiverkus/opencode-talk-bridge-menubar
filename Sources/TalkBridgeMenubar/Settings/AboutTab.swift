import SwiftUI

struct AboutTab: View {
    var currentStatus: () -> BridgeStatus?

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = info?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version", value: appVersion)
                Text("MIT-Lizenz · © Patrick Leiverkus")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Section("Bridge") {
                LabeledContent("Bridge-Version",
                               value: currentStatus()?.version ?? "—")
                LabeledContent("Letzter State",
                               value: currentStatus()?.state.rawValue ?? "—")
            }
            Section("Repos") {
                Link("opencode-talk-bridge",
                     destination: URL(string: "https://github.com/leiverkus/opencode-talk-bridge")!)
                Link("opencode-talk-bridge-menubar",
                     destination: URL(string: "https://github.com/leiverkus/opencode-talk-bridge-menubar")!)
            }
        }
        .formStyle(.grouped)
    }
}
