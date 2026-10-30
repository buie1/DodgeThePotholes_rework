import SwiftUI

/// Shown as a full-screen overlay when `route == .gameOver`.
/// Presented inside `GameView`'s ZStack so the frozen canvas is visible behind it.
struct GameOverView: View {

    let viewModel: GameViewModel
    /// Canvas size from `GameView`'s `GeometryReader`, used for "Play Again" restarts.
    let screenSize: CGSize

    /// Drives the "NEW HIGH SCORE" flash animation.
    @State private var highScoreGlow = false

    var body: some View {
        ZStack {
            // Dim the frozen canvas behind
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                Text("GAME OVER")
                    .font(.pixel(26).weight(.bold))
                    .foregroundStyle(.red)
                    .shadow(color: .red.opacity(0.6), radius: 12)
                    .padding(.bottom, 32)

                // Scores card
                scoresCard

                Spacer()

                // Buttons
                buttonStack
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            if viewModel.isNewHighScore {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    highScoreGlow = true
                }
            }
        }
    }

    // MARK: - Scores card

    private var scoresCard: some View {
        VStack(spacing: 20) {
            if viewModel.isNewHighScore {
                Text("NEW HIGH SCORE!")
                    .font(.pixel(11))
                    .foregroundStyle(highScoreGlow ? Color.yellow : Color.orange)
                    .shadow(color: .yellow.opacity(highScoreGlow ? 0.9 : 0.2), radius: 10)
            }

            ScoreRow(label: "SCORE",    value: "\(viewModel.finalScore)", color: .white)
            ScoreRow(label: "BEST",     value: "\(viewModel.highScore)",  color: .yellow)
            ScoreRow(label: "EARNED",   value: "$\(viewModel.finalMoney)", color: .green)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 32)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 32)
    }

    // MARK: - Buttons

    private var buttonStack: some View {
        VStack(spacing: 14) {
            GameOverButton(title: "PLAY AGAIN", color: .yellow) {
                viewModel.startGame(screenSize: screenSize)
            }
            GameOverButton(title: "MAIN MENU", color: .gray) {
                viewModel.returnToMenu()
            }
        }
    }
}

// MARK: - Helpers

private struct ScoreRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.pixel(10))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.pixel(16))
                .foregroundStyle(color)
        }
    }
}

private struct GameOverButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(13))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: color.opacity(0.5), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GameOverView(viewModel: GameViewModel(), screenSize: CGSize(width: 390, height: 844))
}
