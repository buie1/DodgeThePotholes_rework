#if DEBUG
import SwiftUI

/// In-run DEV controls: a DEV button that opens a panel to change the running game.
/// Debug builds only. Any change marks the run as dev-adjusted (see `GameViewModel.devAdjust`).
struct DevOverlayView: View {

    let viewModel: GameViewModel

    @State private var isOpen = ProcessInfo.processInfo.arguments.contains("-devOverlay")
    @State private var godMode = false
    @State private var autopilot = false
    @State private var showsHitboxes = false
    @State private var timeScale: Double = 1

    var body: some View {
        // The panel sits at the top so it never hides the player's car.
        VStack(spacing: 8) {
            HStack {
                Spacer()
                DevButton { isOpen.toggle() }
            }
            if isOpen { panel }
            Spacer()
        }
        .padding(.horizontal, 12)
        .onAppear(perform: syncFromEngine)
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 10) {
            DevReadout(viewModel: viewModel)

            HStack(spacing: 8) {
                chip("God", isOn: godMode) { godMode.toggle(); adjust { $0.debug.godMode = godMode } }
                chip("Autopilot", isOn: autopilot) {
                    autopilot.toggle()
                    adjust { $0.debug.autopilot = autopilot ? Autopilot() : nil }
                }
                chip("Hitboxes", isOn: showsHitboxes) {
                    showsHitboxes.toggle()
                    viewModel.scene?.showsHitboxes = showsHitboxes
                    viewModel.scene?.debugRedraw()
                }
            }

            Picker("Time scale", selection: $timeScale) {
                ForEach([0.25, 0.5, 1, 2, 4], id: \.self) { Text("\($0.formatted())×").tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: timeScale) { _, scale in adjust { $0.debug.timeScale = scale } }

            HStack(spacing: 8) {
                let isPaused = viewModel.engine?.state == .paused
                button(isPaused ? "Resume" : "Pause") {
                    isPaused ? viewModel.resumeGame() : viewModel.pauseGame()
                }
                button("Step") { adjust { $0.stepWhilePaused() } }
                    .disabled(!isPaused)
                button("+30 s") { adjust { $0.fastForwardSpeedRamp(by: 30) } }
            }

            DevSpawnMenus(viewModel: viewModel)
        }
        .font(.caption.bold())
        .padding(12)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func adjust(_ change: (GameEngine) -> Void) {
        viewModel.devAdjust(change)
    }

    /// Picks up settings a dev scenario already applied.
    private func syncFromEngine() {
        guard let engine = viewModel.engine else { return }
        godMode = engine.debug.godMode
        autopilot = engine.debug.autopilot != nil
        timeScale = engine.debug.timeScale
        showsHitboxes = viewModel.scene?.showsHitboxes ?? false
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isOn ? Color.green.opacity(0.8) : Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

/// Live run stats for the DEV panel: play time, speed, frame rate and seed.
private struct DevReadout: View {
    let viewModel: GameViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var text: String {
        guard let engine = viewModel.engine else { return "" }
        let fps = Int(viewModel.scene?.debugFPS ?? 0)
        let seed = viewModel.devSeed.map(String.init) ?? "random"
        return String(format: "t %.1fs · travel %.2fs · %d fps · seed %@",
                      engine.elapsed, engine.travelDuration, fps, seed)
    }
}
#endif
