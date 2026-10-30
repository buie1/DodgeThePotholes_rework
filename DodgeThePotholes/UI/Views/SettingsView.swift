import SwiftUI

/// Settings hub. Replaces the legacy `SettingsScene`.
struct SettingsView: View {

    var body: some View {
        MenuScreen("SETTINGS") {
            VStack(spacing: 16) {
                NavigationLink(value: MenuDestination.audio) {
                    MenuButtonLabel(title: "AUDIO", color: .cyan)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
