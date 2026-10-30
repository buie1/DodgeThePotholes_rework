import SwiftData
import SwiftUI

@main
struct DodgeThePotholesApp: App {

    /// Saved player progress, shared by every screen.
    @State private var persistence: SwiftDataPersistenceService

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
            MainMenuView(persistence: persistence)
        }
    }
}
