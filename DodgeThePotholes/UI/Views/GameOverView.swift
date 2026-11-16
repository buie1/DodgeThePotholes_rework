import SwiftUI

/// Shown as a full-screen overlay when `route == .gameOver`.
/// Presented inside `GameView`'s ZStack so the frozen canvas is visible behind it.
///
/// Leads with the score and how close it came to the best, then the run's stats,
/// so the next goal is the first thing the player sees.
struct GameOverView: View {

    let viewModel: GameViewModel
    /// Canvas size from `GameView`'s `GeometryReader`, used for "Play Again" restarts.
    let screenSize: CGSize

    /// Drives the "NEW BEST" flash animation.
    @State private var highScoreGlow = false

    var body: some View {
        ZStack {
            // Dim the frozen canvas behind
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text(viewModel.isNewHighScore ? "NEW BEST!" : "GAME OVER")
                    .font(.pixel(24).weight(.bold))
                    .foregroundStyle(viewModel.isNewHighScore ? .yellow : .red)
                    .shadow(color: (viewModel.isNewHighScore ? Color.yellow : .red).opacity(0.6), radius: 12)

                scoreBlock

                RunStatsGrid(time: viewModel.finalTime, stats: viewModel.finalStats)

                Text("EARNED $\(viewModel.finalMoney)")
                    .font(.pixel(10))
                    .foregroundStyle(.green)

                Spacer()

                VStack(spacing: 14) {
                    MenuButton(title: "PLAY AGAIN", color: .yellow) {
                        viewModel.startGame(screenSize: screenSize)
                    }
                    MenuButton(title: "MAIN MENU", color: .gray) {
                        viewModel.returnToMenu()
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            if viewModel.isNewHighScore {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    highScoreGlow = true
                }
            }
        }
    }

    // MARK: - Score

    private var scoreBlock: some View {
        VStack(spacing: 10) {
            Text(viewModel.finalScore.formatted())
                .font(.pixel(32))
                .foregroundStyle(.white)
            Text(bestLine)
                .font(.pixel(9))
                .foregroundStyle(viewModel.isNewHighScore
                                 ? (highScoreGlow ? Color.yellow : .orange)
                                 : .white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    /// The next goal: how far the run beat the old best, or how far short it fell.
    private var bestLine: String {
        if viewModel.isNewHighScore {
            let margin = viewModel.finalScore - viewModel.previousBest
            return viewModel.previousBest > 0 ? "+\(margin.formatted()) OVER YOUR OLD BEST" : "YOUR FIRST BEST SCORE"
        }
        if let toBeat = viewModel.pointsToBeatBest {
            return "\(toBeat.formatted()) TO BEAT YOUR BEST"
        }
        return "BEST \(viewModel.highScore.formatted())"
    }
}

#Preview {
    GameOverView(viewModel: GameViewModel(persistence: SwiftDataPersistenceService.inMemory()),
                 screenSize: CGSize(width: 390, height: 844))
}
