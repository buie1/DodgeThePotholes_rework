import SwiftUI

/// The pause screen (Resume / Main Menu), then a 3-2-1 countdown before play continues.
struct PauseOverlayView: View {
    let viewModel: GameViewModel

    var body: some View {
        switch viewModel.pauseState {
        case .running:
            EmptyView()

        case .paused:
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 28) {
                    Text("PAUSED")
                        .font(.pixel(24).weight(.bold))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 12)
                    VStack(spacing: 14) {
                        MenuButton(title: "RESUME", color: .yellow, action: viewModel.resumeAfterCountdown)
                        MenuButton(title: "MAIN MENU", color: .gray, action: viewModel.returnToMenu)
                    }
                    .padding(.horizontal, 32)
                }
            }

        case .countingDown(let number):
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                Text("\(number)")
                    .font(.pixel(64))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.7), radius: 16)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("pause.countdown")
            }
            // Touches wait for the countdown; steering resumes with play.
            .allowsHitTesting(true)
        }
    }
}

/// The HUD's pause button, shown during play.
struct PauseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("II")
                .font(.pixel(12))
                .foregroundStyle(.white)
                .frame(width: 40, height: 32)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("hud.pause")
    }
}

#Preview {
    let viewModel = GameViewModel(persistence: SwiftDataPersistenceService.inMemory())
    return PauseOverlayView(viewModel: viewModel)
        .background(.black)
}
