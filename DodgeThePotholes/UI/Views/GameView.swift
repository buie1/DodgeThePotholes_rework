import SwiftUI
import SpriteKit

/// Full-screen game presented while `route == .playing` or `.gameOver`.
///
/// Rendering: a `SpriteView` shows `GameRenderScene`, which also drives the
/// engine's clock. The world is 750 units wide with the screen's aspect ratio,
/// so the scene fills the screen exactly. HUD and effect overlays are SwiftUI
/// components from `UI/Components`.
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

                if viewModel.isDrunkMode {
                    DrunkGogglesOverlay()
                }

                HUDOverlayView(viewModel: viewModel)
                    .padding(.top, geo.safeAreaInsets.top)

                if let alert = viewModel.activeAlert {
                    AlertBannerView(alert: alert)
                }

                if let index = viewModel.textMessageIndex {
                    TextMessageOverlayView(index: index)
                }

                if viewModel.route == .gameOver {
                    GameOverView(viewModel: viewModel, screenSize: geo.size)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: viewModel.activeAlert)
            .animation(.spring(duration: 0.3), value: viewModel.textMessageIndex)
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
}

#Preview {
    GameView(viewModel: GameViewModel())
}
