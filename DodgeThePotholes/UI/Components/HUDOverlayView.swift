import SwiftUI

/// In-game heads-up display: score, money and combo, best, lives, and the active power-up timer.
/// Laid out inside the safe area.
struct HUDOverlayView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    stat("SCORE", "\(viewModel.score)", color: .white, alignment: .leading)
                    money
                    if let combo = viewModel.engine?.combo {
                        ComboMeterView(combo: combo)
                    }
                }
                Spacer()
                stat("BEST", "\(viewModel.highScore)", color: .yellow, alignment: .center)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("hud.best")
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
        }
        .allowsHitTesting(false)
    }

    /// Money banked this run. Kept in the top bar so it never covers the car.
    private var money: some View {
        HStack(spacing: 6) {
            SpriteImage(.dollar)
                .frame(height: 16)
            Text("$\(viewModel.money)")
                .font(.pixel(10))
                .foregroundStyle(.yellow)
        }
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
