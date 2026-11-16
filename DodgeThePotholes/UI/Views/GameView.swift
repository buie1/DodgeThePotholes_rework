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
    @Environment(\.scenePhase) private var scenePhase

    /// How long the full-screen cover takes to slide in. Play begins after it, so a run
    /// never ticks while the road is still moving into view.
    private static let slideInDuration: Duration = .milliseconds(600)

    // Track whether the run has been prepared for this presentation.
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

                // Steering takes touches on open road only. It sits under the HUD, the DEV
                // panel and game-over, so their controls get their own taps first.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(steeringGesture(width: screenSize.width))

                // HUD and messages stay inside the safe area, clear of the Dynamic Island.
                overlays
                    .padding(.top, insets.top)
                    .padding(.bottom, insets.bottom)

                PauseOverlayView(viewModel: viewModel)

                if viewModel.route == .gameOver {
                    GameOverView(viewModel: viewModel, screenSize: screenSize)
                }
            }
            .ignoresSafeArea()
            // Leaving the app (home, a call, the app switcher) pauses the run.
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { viewModel.pause() }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.prepareGame(screenSize: screenSize)
            }
            .task {
                try? await Task.sleep(for: Self.slideInDuration)
                viewModel.beginRun()
            }
        }
    }

    // MARK: - Overlays

    private var overlays: some View {
        ZStack {
            HUDOverlayView(viewModel: viewModel)

            if viewModel.isAwaitingStart {
                Text("GET READY")
                    .font(.pixel(18))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 10)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if let alert = viewModel.activeAlert {
                AlertBannerView(alert: alert)
            }

            if let index = viewModel.textMessageIndex {
                TextMessageOverlayView(index: index)
            }

            if viewModel.route == .playing, viewModel.pauseState == .running, !viewModel.isAwaitingStart {
                PauseButton(action: viewModel.pause)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 58)
            }

            #if DEBUG
            if viewModel.route == .playing {
                DevOverlayView(viewModel: viewModel)
                    .padding(.top, 64)
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.6), value: viewModel.activeAlert)
        .animation(.easeOut(duration: 0.2), value: viewModel.isAwaitingStart)
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
