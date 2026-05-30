import SwiftUI

struct WakeTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Wachhalten") {
                Picker("Modus", selection: $settings.wakeMode) {
                    ForEach(WakeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("‚Nur wenn Bridge läuft‘ koppelt die Wachhaltung an den Bridge-Zustand (starting / polling / working).")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
