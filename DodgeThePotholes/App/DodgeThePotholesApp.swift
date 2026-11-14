import SwiftData
import SwiftUI

@main
struct DodgeThePotholesApp: App {

    /// Saved player progress, shared by every screen.
    @State private var persistence: SwiftDataPersistenceService
    /// Game Center sign-in and scores, shared by the game and the leaderboard screen.
    @State private var leaderboard = GameCenterLeaderboardService()

    #if DEBUG
    /// Dev scenario from the launch arguments; the game starts it straight away.
    private let launchScenario: DevScenario?
    #endif

    init() {
        #if DEBUG
        do {
            launchScenario = try DevScenario.fromLaunchArguments(ProcessInfo.processInfo.arguments)
        } catch {
            preconditionFailure("Dev scenario: \(error)")
        }
        if let launchScenario, !launchScenario.useRealProfile {
            // Throwaway in-memory profile: nothing a dev run does reaches the real save.
            let store = SwiftDataPersistenceService.inMemory(defaults: UserDefaults(suiteName: "dev-scenario")!)
            store.applyDevSetup(launchScenario)
            _persistence = State(initialValue: store)
            return
        }
        #endif
        do {
            let container = try SwiftDataPersistenceService.makeContainer()
            _persistence = State(initialValue: SwiftDataPersistenceService(container: container))
        } catch {
            fatalError("Could not open the player data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainMenuView(persistence: persistence, leaderboard: leaderboard)
                #if DEBUG
                .environment(\.devLaunchScenario, launchScenario)
                #endif
        }
    }
}
