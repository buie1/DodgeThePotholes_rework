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
        // This reader respects the safe area, so its insets are real; the content below
        // ignores it so the world fills the whole display.
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let screenSize = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                                    height: geo.size.height + insets.top + insets.bottom)
            ZStack {
                Color.black

                gameLayer

                if viewModel.isDrunkMode {
                    DrunkGogglesOverlay()
                }

                // HUD and messages stay inside the safe area, clear of the Dynamic Island.
                overlays
                    .padding(.top, insets.top)
                    .padding(.bottom, insets.bottom)

                if viewModel.route == .gameOver {
                    GameOverView(viewModel: viewModel, screenSize: screenSize)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.startGame(screenSize: screenSize)
            }
            .gesture(steeringGesture(width: screenSize.width))
        }
    }

    // MARK: - Overlays

    private var overlays: some View {
        ZStack {
            HUDOverlayView(viewModel: viewModel)

            if let alert = viewModel.activeAlert {
                AlertBannerView(alert: alert)
            }

            if let index = viewModel.textMessageIndex {
                TextMessageOverlayView(index: index)
            }

            #if DEBUG
            if viewModel.route == .playing {
                DevOverlayView(viewModel: viewModel)
                    .padding(.top, 64)
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.6), value: viewModel.activeAlert)
        .animation(.spring(duration: 0.3), value: viewModel.textMessageIndex)
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
    GameView(viewModel: GameViewModel(persistence: SwiftDataPersistenceService.inMemory()))
}
