import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let bridgeService: BridgeService
    var currentStatus: () -> BridgeStatus?
    var onServiceChanged: () -> Void

    var body: some View {
        TabView {
            BridgeTab(settings: settings,
                      bridgeService: bridgeService,
                      onServiceChanged: onServiceChanged)
                .tabItem { Label("Bridge", systemImage: "link") }
            WakeTab(settings: settings)
                .tabItem { Label("Wachhalten", systemImage: "bolt") }
            GeneralTab()
                .tabItem { Label("Allgemein", systemImage: "gear") }
            AboutTab(currentStatus: currentStatus)
                .tabItem { Label("Info", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 360)
        .padding()
    }
}
