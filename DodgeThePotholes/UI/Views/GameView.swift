import SwiftUI
import SpriteKit

/// Full-screen game presented while `route == .playing` or `.gameOver`.
///
/// Rendering: a `SpriteView` shows `GameRenderScene`, which also drives the
/// engine's clock. The world is 750 units wide with the screen's aspect ratio,
/// so the scene fills the screen exactly. HUD and effect overlays are SwiftUI.
///
/// Input: tilt steers by default (`MotionService`). `DragGesture(minimumDistance: 0)`
///   maps horizontal translation to a [-1, 1] override; a tap honks the horn.
struct GameView: View {

    @Bindable var viewModel: GameViewModel

    // Track whether the engine has been started for this presentation.
    @State private var hasStarted = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                gameLayer

                HUDOverlay(viewModel: viewModel)
                    .padding(.top, geo.safeAreaInsets.top)

                if viewModel.isDrunkMode {
                    drunkOverlay
                }

                if let idx = viewModel.textMessageIndex {
                    TextMessageOverlay(index: idx)
                }

                if viewModel.route == .gameOver {
                    GameOverView(viewModel: viewModel, screenSize: geo.size)
                }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.startGame(screenSize: geo.size)
            }
            .gesture(steeringGesture(width: geo.size.width))
        }
        // Full-screen geometry so the world matches the whole display's aspect ratio.
        .ignoresSafeArea()
    }

    // MARK: - SpriteKit layer

    /// The game world. Touches pass through to the SwiftUI steering gesture.
    @ViewBuilder
    private var gameLayer: some View {
        if let scene = viewModel.scene {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .id(ObjectIdentifier(scene))   // fresh view for each new game
                .allowsHitTesting(false)
        }
    }

    // MARK: - Steering gesture

    /// Drag sideways to steer (overrides tilt while the finger is down);
    /// a touch that barely moves is a tap, which honks the horn.
    private func steeringGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                viewModel.updateDrag(Double(value.translation.width) / Double(width / 2))
            }
            .onEnded { value in
                let travel = hypot(value.translation.width, value.translation.height)
                viewModel.endDrag(wasTap: travel < GameConfig.tapMaxTravel)
            }
    }

    // MARK: - Drunk overlay

    private var drunkOverlay: some View {
        Color.green
            .opacity(0.18)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - HUD Overlay

private struct HUDOverlay: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                // Score — top-left
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.score)")
                        .font(.custom("Press Start 2P", size: 14))
                        .foregroundStyle(.white)
                }

                Spacer()

                // High score — top-centre
                VStack(spacing: 2) {
                    Text("BEST")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.highScore)")
                        .font(.custom("Press Start 2P", size: 14))
                        .foregroundStyle(.yellow)
                }

                Spacer()

                // Lives — top-right
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LIVES")
                        .font(.custom("Press Start 2P", size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 4) {
                        ForEach(0..<max(0, viewModel.lives), id: \.self) { _ in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Active power-up timer bar
            if let pu = viewModel.activePowerUp {
                PowerUpTimerBar(state: pu)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            Spacer()

            // Money counter — bottom
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.money)")
                    .font(.custom("Press Start 2P", size: 11))
                    .foregroundStyle(.yellow)
            }
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Power-up timer bar

private struct PowerUpTimerBar: View {
    let state: PowerUpState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: geo.size.width * state.progress, height: 6)
                    .animation(.linear(duration: 0.1), value: state.progress)
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        switch state.type {
        case .monsterTruck: return .orange
        case .multiplier:   return .yellow
        case .wrap:         return .cyan
        case .booze:        return .green
        case .oneUp:        return .pink
        }
    }
}

// MARK: - Text message overlay

private struct TextMessageOverlay: View {
    let index: Int

    private let messages = [
        "📱 INCOMING TEXT!",
        "Never gonna give you up…",
        "Mom: Are you driving?!",
        "🚨 ROAD RAGE ALERT 🚨",
        "Check your notifications!"
    ]

    var body: some View {
        VStack {
            Spacer()
            Text(messages[index % messages.count])
                .font(.custom("Press Start 2P", size: 11))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 8)
                .padding(.bottom, 60)
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: index)
    }
}

#Preview {
    GameView(viewModel: {
        let vm = GameViewModel()
        return vm
    }())
}
