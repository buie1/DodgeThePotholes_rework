import XCTest
@testable import DodgeThePotholes

/// The DEV menu's scenario editing, dev runs and real-profile tools.
@MainActor
final class DevMenuViewModelTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var viewModel: DevMenuViewModel!

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        viewModel = DevMenuViewModel(persistence: persistence, leaderboard: MockLeaderboardService())
    }

    func testSelectingAPresetLoadsIt() {
        viewModel.selectPreset("potholeRain")
        XCTAssertEqual(viewModel.presetName, "potholeRain")
        XCTAssertEqual(viewModel.onlyObstacle, .single(.pothole))
        XCTAssertTrue(viewModel.scenario.godMode)

        viewModel.selectPreset(nil)
        XCTAssertNil(viewModel.onlyObstacle)
        XCTAssertFalse(viewModel.scenario.godMode)
    }

    func testFormBindingsEditTheScenario() {
        viewModel.onlyPowerUp = .phone
        XCTAssertEqual(viewModel.scenario.powerUps?.map(\.0), [.phone])
        viewModel.onlyPowerUp = nil
        XCTAssertNil(viewModel.scenario.powerUps)

        viewModel.seedText = "1234"
        XCTAssertEqual(viewModel.scenario.seed, 1234)
        viewModel.seedText = ""
        XCTAssertNil(viewModel.scenario.seed)

        viewModel.toggleStart(.monsterTruck)
        XCTAssertTrue(viewModel.startsWith(.monsterTruck))
        viewModel.toggleStart(.monsterTruck)
        XCTAssertFalse(viewModel.startsWith(.monsterTruck))
    }

    func testThrowawayRunLeavesTheRealProfileAlone() {
        viewModel.scenario = DevScenario(seed: 3, godMode: true, bank: 50_000)
        viewModel.startRun()
        let game = try! XCTUnwrap(viewModel.runViewModel)
        XCTAssertTrue(viewModel.isShowingRun)
        XCTAssertEqual(game.devScenario?.seed, 3)

        game.startGame(screenSize: CGSize(width: 402, height: 874))
        game.engineDidEnd(game.engine!, finalScore: 777, moneyEarned: 10)
        XCTAssertEqual(persistence.money, 0, "the bank went to the throwaway profile")
        XCTAssertTrue(persistence.runs.isEmpty)

        viewModel.isShowingRun = false
        XCTAssertNil(viewModel.runViewModel)
    }

    func testProfileToolsEditTheRealStore() {
        let store = SwiftDataPersistenceService.inMemory(defaults: UserDefaults(suiteName: "dev-menu-tests")!)
        let menu = DevMenuViewModel(persistence: store, leaderboard: MockLeaderboardService())
        XCTAssertTrue(menu.hasProfileTools)
        XCTAssertFalse(viewModel.hasProfileTools, "mocks have no tools")

        menu.addMoney(10_000)
        menu.unlockEverything()
        store.recordRun(score: 900, moneyEarned: 5)
        XCTAssertEqual(menu.realMoney, 10_005)
        XCTAssertTrue(store.hasTank)

        menu.resetProgress()
        XCTAssertEqual(store.money, 0)
        XCTAssertEqual(store.highScore, 0)
        XCTAssertFalse(store.hasTank)
        XCTAssertTrue(store.bestRuns(limit: 10).isEmpty)
    }
}
