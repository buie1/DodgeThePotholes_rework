import SwiftData
import SwiftUI

@main
struct DodgeThePotholesApp: App {

    /// Saved player progress, shared by every screen.
    @State private var persistence: SwiftDataPersistenceService
    /// Game Center sign-in and scores, shared by the game and the leaderboard screen.
    @State private var leaderboard = GameCenterLeaderboardService()

    init() {
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
        }
    }
}
