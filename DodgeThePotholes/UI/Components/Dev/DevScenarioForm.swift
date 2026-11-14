#if DEBUG
import SwiftUI

/// Form sections editing a `DevScenario`: run, start-with power-ups, spawns, profile.
/// Debug builds only.
struct DevScenarioForm: View {

    @Bindable var viewModel: DevMenuViewModel

    var body: some View {
        Section("Run") {
            LabeledContent("Seed") {
                TextField("Random", text: $viewModel.seedText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            Toggle("God mode", isOn: $viewModel.scenario.godMode)
            Toggle("Autopilot", isOn: $viewModel.scenario.autopilot)
            Toggle("Hitboxes", isOn: $viewModel.scenario.hitboxes)
            LabeledContent("Time scale \(viewModel.scenario.timeScale.formatted())×") {
                Slider(value: $viewModel.scenario.timeScale, in: 0.25...4, step: 0.25)
            }
            LabeledContent("Start at \(Int(startElapsed.wrappedValue)) s") {
                Slider(value: startElapsed, in: 0...180, step: 10)
            }
            Stepper("Lives: \(lives.wrappedValue)", value: lives, in: 1...9)
        }

        Section("Start With") {
            ForEach(PowerUpType.devChoices, id: \.self) { type in
                Toggle(type.devName, isOn: Binding(
                    get: { viewModel.startsWith(type) },
                    set: { _ in viewModel.toggleStart(type) }
                ))
            }
        }

        Section("Spawns") {
            Picker("Obstacles", selection: $viewModel.onlyObstacle) {
                Text("Normal").tag(ObstacleSpawn?.none)
                ForEach(ObstacleSpawn.devChoices, id: \.self) { Text($0.devName).tag(Optional($0)) }
            }
            Picker("Roadside", selection: $viewModel.onlyEnvironment) {
                Text("Normal").tag(EnvSpawnType?.none)
                ForEach(EnvSpawnType.devChoices, id: \.self) { Text($0.devName).tag(Optional($0)) }
            }
            Picker("Power-ups", selection: $viewModel.onlyPowerUp) {
                Text("Normal").tag(PowerUpSpawn?.none)
                ForEach(PowerUpSpawn.devChoices, id: \.self) { Text($0.devName).tag(Optional($0)) }
            }
        }

        Section("Profile") {
            Toggle("Use real profile", isOn: $viewModel.scenario.useRealProfile)
            if !viewModel.scenario.useRealProfile {
                Stepper("Bank: $\(bank.wrappedValue)", value: bank, in: 0...1_000_000, step: 1_000)
                Toggle("Unlock everything", isOn: $viewModel.scenario.unlockAll)
            }
        }
    }

    // MARK: - Optional-field bindings

    private var startElapsed: Binding<Double> {
        Binding(get: { viewModel.scenario.startElapsed ?? 0 },
                set: { viewModel.scenario.startElapsed = $0 > 0 ? $0 : nil })
    }

    private var lives: Binding<Int> {
        Binding(get: { viewModel.scenario.lives ?? GameTuning.bundled.lives.start },
                set: { viewModel.scenario.lives = $0 })
    }

    private var bank: Binding<Int> {
        Binding(get: { viewModel.scenario.bank ?? 0 },
                set: { viewModel.scenario.bank = $0 })
    }
}
#endif
