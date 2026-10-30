import SwiftUI

/// Entry point the player sees on launch.
/// Owns `GameViewModel` and presents `GameView` as a full-screen cover
/// when a session starts.
struct MainMenuView: View {

    @State private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            roadStripes

            VStack(spacing: 32) {
                Spacer()
                titleBlock
                Spacer()
                buttonStack
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingGame) {
            GameView(viewModel: viewModel)
        }
    }

    // MARK: - Sub-views

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("DODGE THE")
                .font(.pixel(22).weight(.bold))
                .foregroundStyle(.white)
            Text("POTHOLES")
                .font(.pixel(22).weight(.bold))
                .foregroundStyle(.yellow)
        }
        .multilineTextAlignment(.center)
        .shadow(color: .yellow.opacity(0.6), radius: 12)
    }

    private var buttonStack: some View {
        VStack(spacing: 16) {
            MenuButton(title: "NEW GAME", color: .yellow) {
                viewModel.navigateToGame()
            }
            MenuButton(title: "LEADERBOARD", color: .cyan)  { /* Phase 5 */ }
            MenuButton(title: "SHOP",        color: .green) { /* Phase 2 */ }
            MenuButton(title: "SETTINGS",    color: .gray)  { /* Phase 2 */ }
        }
    }

    /// Decorative vertical road stripes in the background.
    private var roadStripes: some View {
        GeometryReader { geo in
            let stripeCount = 5
            let w = geo.size.width / CGFloat(stripeCount + 1)
            HStack(spacing: w - 3) {
                ForEach(0..<stripeCount, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reusable menu button

private struct MenuButton: View {
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
    MainMenuView()
}
