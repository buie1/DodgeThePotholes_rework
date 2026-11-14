#if DEBUG
import SwiftUI

/// The DEV menu: pick or edit a scenario, start a dev run, or edit the real profile.
/// Debug builds only; opened from the DEV button on the main menu.
struct DevMenuView: View {

    @Bindable var viewModel: DevMenuViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Preset", selection: presetBinding) {
                        Text("None").tag(String?.none)
                        ForEach(DevScenario.presets, id: \.name) { preset in
                            Text(preset.name).tag(Optional(preset.name))
                        }
                    }
                } footer: {
                    Text("Presets use seed 42, so they play the same road every time.")
                }

                DevScenarioForm(viewModel: viewModel)

                Section {
                    Button("Start Run", action: viewModel.startRun)
                        .bold()
                } footer: {
                    Text(viewModel.scenario.useRealProfile
                         ? "Runs on your real profile are not recorded."
                         : "Runs use a throwaway profile. Dev runs never reach Game Center.")
                }

                DevProfileToolsSection(viewModel: viewModel)
            }
            .navigationTitle("Dev Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingRun) {
            if let game = viewModel.runViewModel {
                GameView(viewModel: game)
            }
        }
    }

    private var presetBinding: Binding<String?> {
        Binding(get: { viewModel.presetName }, set: { viewModel.selectPreset($0) })
    }
}

/// Adds the red DEV button that opens the DEV menu. Debug builds only.
struct DevMenuAccess: ViewModifier {

    @State private var viewModel: DevMenuViewModel
    @State private var isShowingMenu = false

    init(persistence: any PersistenceServiceProtocol, leaderboard: any LeaderboardServiceProtocol) {
        _viewModel = State(initialValue: DevMenuViewModel(persistence: persistence, leaderboard: leaderboard))
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                DevButton { isShowingMenu = true }
                    .padding(.trailing, 16)
            }
            .sheet(isPresented: $isShowingMenu) {
                DevMenuView(viewModel: viewModel)
            }
            .task {
                // `-devMenu` opens the menu on launch (for screenshots and quick access).
                if ProcessInfo.processInfo.arguments.contains("-devMenu") { isShowingMenu = true }
            }
    }
}

/// The small red DEV button shown in debug builds.
struct DevButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("DEV")
                .font(.pixel(9))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.red.opacity(0.85)))
        }
        .accessibilityLabel("Developer mode")
    }
}

#Preview {
    DevMenuView(viewModel: DevMenuViewModel(persistence: SwiftDataPersistenceService.inMemory(),
                                            leaderboard: GameCenterLeaderboardService()))
}
#endif
