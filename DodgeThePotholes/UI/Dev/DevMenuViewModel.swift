#if DEBUG
import Foundation
import Observation

/// `@Observable` state for the DEV menu: the scenario being edited, the dev run it
/// starts, and edits to the real profile. Debug builds only.
///
/// Each run gets its own `GameViewModel`, on a fresh throwaway profile unless the
/// scenario says `useRealProfile`, so the main game's state is never touched.
@Observable
@MainActor
final class DevMenuViewModel {

    /// The preset the scenario was loaded from, if any.
    private(set) var presetName: String?
    /// The scenario the next run uses; edited by the form.
    var scenario = DevScenario()
    /// The game for the current dev run; drives the full-screen cover.
    private(set) var runViewModel: GameViewModel?

    private let persistence: any PersistenceServiceProtocol
    private let leaderboard: any LeaderboardServiceProtocol

    /// - Parameters:
    ///   - persistence: The real saved profile, for `useRealProfile` runs and the profile tools.
    ///   - leaderboard: Passed to dev runs, which never submit to it.
    init(persistence: any PersistenceServiceProtocol, leaderboard: any LeaderboardServiceProtocol) {
        self.persistence = persistence
        self.leaderboard = leaderboard
    }

    // MARK: - Scenario

    /// Loads a preset, or an empty scenario for `nil`.
    func selectPreset(_ name: String?) {
        presetName = name
        scenario = name.flatMap(DevScenario.preset(named:)) ?? DevScenario()
    }

    /// The only obstacle that spawns, or `nil` for the normal pool.
    var onlyObstacle: ObstacleSpawn? {
        get { scenario.obstacles?.count == 1 ? scenario.obstacles?.first?.0 : nil }
        set { scenario.obstacles = newValue.map { [($0, 1)] } }
    }

    /// The only roadside spawn, or `nil` for the normal pool.
    var onlyEnvironment: EnvSpawnType? {
        get { scenario.environment?.count == 1 ? scenario.environment?.first?.0 : nil }
        set { scenario.environment = newValue.map { [($0, 1)] } }
    }

    /// The only power-up roll, or `nil` for the normal pool.
    var onlyPowerUp: PowerUpSpawn? {
        get { scenario.powerUps?.count == 1 ? scenario.powerUps?.first?.0 : nil }
        set { scenario.powerUps = newValue.map { [($0, 1)] } }
    }

    /// The seed as text; empty means a random seed.
    var seedText: String {
        get { scenario.seed.map(String.init) ?? "" }
        set { scenario.seed = UInt64(newValue.filter(\.isNumber)) }
    }

    func startsWith(_ type: PowerUpType) -> Bool { scenario.startPowerUps.contains(type) }

    func toggleStart(_ type: PowerUpType) {
        if let index = scenario.startPowerUps.firstIndex(of: type) {
            scenario.startPowerUps.remove(at: index)
        } else {
            scenario.startPowerUps.append(type)
        }
    }

    // MARK: - Runs

    /// Starts a dev run of `scenario`.
    func startRun() {
        let store: any PersistenceServiceProtocol
        if scenario.useRealProfile {
            store = persistence
        } else {
            let throwaway = SwiftDataPersistenceService.inMemory(defaults: UserDefaults(suiteName: "dev-menu")!)
            throwaway.applyDevSetup(scenario)
            store = throwaway
        }
        let game = GameViewModel(persistence: store, leaderboard: leaderboard)
        game.devScenario = scenario
        game.navigateToGame()
        runViewModel = game
    }

    /// Whether a dev run is on screen. Clearing it ends the run.
    var isShowingRun: Bool {
        get { runViewModel?.isShowingGame ?? false }
        set {
            guard !newValue else { return }
            runViewModel?.isShowingGame = false
            runViewModel = nil
        }
    }

    // MARK: - Real profile tools

    /// The real profile's bank balance.
    var realMoney: Int { persistence.money }

    private var tools: (any DevProfileTools)? { persistence as? any DevProfileTools }

    /// Whether the real profile can be edited (false for test mocks).
    var hasProfileTools: Bool { tools != nil }

    func addMoney(_ amount: Int) { tools?.devAddMoney(amount) }

    func unlockEverything() { tools?.devUnlockAll(catalog: .bundled) }

    func resetProgress() { tools?.devResetProgress() }
}
#endif
