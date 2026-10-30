import SwiftUI

/// Music and sound-effect switches, plus a picker over the songs the player owns.
/// Replaces the legacy `AudioScene`.
struct AudioSettingsView: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        MenuScreen("AUDIO", titleColor: .cyan) {
            VStack(spacing: 28) {
                PixelToggle(title: "MUSIC", isOn: $viewModel.isMusicEnabled)
                PixelToggle(title: "SOUND FX", isOn: $viewModel.isSFXEnabled)
                songPicker
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Song picker

    private var songPicker: some View {
        VStack(spacing: 16) {
            Text("SONG")
                .font(.pixel(10))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                arrowButton("◀", label: "Previous song", action: viewModel.previousSong)
                Spacer()
                Text(viewModel.displayName(of: viewModel.selectedSong).uppercased())
                    .font(.pixel(11))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Spacer()
                arrowButton("▶", label: "Next song", action: viewModel.nextSong)
            }

            Text("\(viewModel.ownedSongs.count) OWNED · BUY MORE IN THE SHOP")
                .font(.pixel(7))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func arrowButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.pixel(16))
                .foregroundStyle(viewModel.ownedSongs.count > 1 ? .white : .white.opacity(0.25))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.ownedSongs.count < 2)
        .accessibilityLabel(label)
    }
}

// MARK: - Helpers

/// An on/off row in the pixel font.
private struct PixelToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.pixel(12))
                .foregroundStyle(.white)
        }
        .tint(.green)
    }
}

#Preview {
    NavigationStack {
        AudioSettingsView(viewModel: SettingsViewModel(persistence: SwiftDataPersistenceService.inMemory()))
    }
}
