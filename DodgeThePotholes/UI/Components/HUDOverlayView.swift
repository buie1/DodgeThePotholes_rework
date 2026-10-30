import SwiftUI

/// In-game heads-up display: score, best, lives, active power-up timer, and money.
struct HUDOverlayView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                stat("SCORE", "\(viewModel.score)", color: .white, alignment: .leading)
                Spacer()
                stat("BEST", "\(viewModel.highScore)", color: .yellow, alignment: .center)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    label("LIVES")
                    LivesDisplayView(lives: viewModel.lives)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let powerUp = viewModel.activePowerUp {
                PowerUpTimerBar(state: powerUp)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 6) {
                SpriteImage(.dollar)
                    .frame(height: 20)
                Text("$ \(viewModel.money)")
                    .font(.pixel(11))
                    .foregroundStyle(.yellow)
            }
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }

    private func stat(_ title: String, _ value: String, color: Color,
                      alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            label(title)
            Text(value)
                .font(.pixel(14))
                .foregroundStyle(color)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.pixel(8))
            .foregroundStyle(.white.opacity(0.7))
    }
}

#Preview {
    HUDOverlayView(viewModel: GameViewModel(persistence: SwiftDataPersistenceService.inMemory()))
        .background(.black)
}
