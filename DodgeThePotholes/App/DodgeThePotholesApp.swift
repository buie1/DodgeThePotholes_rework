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
        let wantsFreshProfile = ProcessInfo.processInfo.arguments.contains("-freshProfile")
        if wantsFreshProfile || launchScenario.map({ !$0.useRealProfile }) == true {
            // Throwaway in-memory profile: nothing a dev run (or a UI test) does reaches the
            // real save. `-freshProfile` asks for one without starting a scenario.
            let store = SwiftDataPersistenceService.inMemory(defaults: UserDefaults(suiteName: "dev-scenario")!)
            if let launchScenario { store.applyDevSetup(launchScenario) }
            // `-devBank <amount>` funds the throwaway profile, e.g. for Shop UI tests.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-devBank"), arguments.indices.contains(index + 1),
               let amount = Int(arguments[index + 1]) {
                store.devSetMoney(amount)
            }
            // Dev runs and UI tests start past the first-launch onboarding unless they test it.
            if launchScenario != nil || arguments.contains("-skipOnboarding") {
                store.hasChosenControls = true
                store.tutorialStatus = .done
            }
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
