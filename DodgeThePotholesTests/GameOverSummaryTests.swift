import XCTest
@testable import DodgeThePotholes

/// Run stats, the game-over summary, and starting a run after the slide-in.
@MainActor
final class GameOverSummaryTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private let screen = CGSize(width: 402, height: 874)
    private var playerPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset) }

    private var persistence: MockPersistenceService!
    private var viewModel: GameViewModel!

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        viewModel = GameViewModel(persistence: persistence, audio: MockAudioService(), haptics: MockHapticService(),
                                  motion: MockMotionService(), leaderboard: MockLeaderboardService())
    }

    // MARK: - Run stats

    func testEngineCountsTheRun() {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        engine.insert(CoinEntity(id: UUID(), position: playerPoint, size: CGSize(width: 12.5, height: 25), velocity: .zero))
        engine.activatePowerUp(.monsterTruck)
        engine.update(deltaTime: 0.016)
        engine.insert(ObstacleEntity(id: UUID(), position: playerPoint, size: ObstacleType.movingCar.size,
                                     velocity: .zero, type: .movingCar))
        engine.update(deltaTime: 0.016)

        XCTAssertEqual(engine.stats, RunStats(coins: 1, smashed: 1, scared: 0, powerUps: 1))
        engine.start()
        XCTAssertEqual(engine.stats, RunStats(), "a new run starts from zero")
    }

    // MARK: - Summary

    func testShortOfTheBestShowsPointsToBeatIt() {
        persistence.highScore = 1_000
        viewModel = GameViewModel(persistence: persistence, audio: MockAudioService(), haptics: MockHapticService(),
                                  motion: MockMotionService(), leaderboard: MockLeaderboardService())
        viewModel.startGame(screenSize: screen)
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 760, moneyEarned: 5)

        XCTAssertFalse(viewModel.isNewHighScore)
        XCTAssertEqual(viewModel.previousBest, 1_000)
        XCTAssertEqual(viewModel.pointsToBeatBest, 241)
    }

    func testNewBestKeepsTheOldBestForTheMargin() {
        persistence.highScore = 500
        viewModel = GameViewModel(persistence: persistence, audio: MockAudioService(), haptics: MockHapticService(),
                                  motion: MockMotionService(), leaderboard: MockLeaderboardService())
        viewModel.startGame(screenSize: screen)
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 820, moneyEarned: 5)

        XCTAssertTrue(viewModel.isNewHighScore)
        XCTAssertEqual(viewModel.previousBest, 500)
        XCTAssertNil(viewModel.pointsToBeatBest)
        XCTAssertEqual(viewModel.highScore, 820)
    }

    func testClockFormat() {
        XCTAssertEqual(RunStatsGrid.clock(7.9), "0:07")
        XCTAssertEqual(RunStatsGrid.clock(83), "1:23")
    }

    func testEachRunRereadsTheBestScore() {
        viewModel.startGame(screenSize: screen)
        persistence.highScore = 9_000          // e.g. set from the DEV menu
        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.highScore, 9_000)
    }

    func testFirstRunsStartSlowerThenNormal() {
        let beginner = GameTuning.bundled.beginner
        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.engine?.travelDuration, beginner.startTravelDuration, "a new player's first run")

        for score in 1...beginner.runs { persistence.recordRun(score: score, moneyEarned: 0) }
        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.engine?.travelDuration, GameTuning.bundled.speed.startTravelDuration, "normal after \(beginner.runs) runs")
    }

    // MARK: - Starting after the slide-in

    func testPreparedRunWaitsForBeginRun() {
        viewModel.prepareGame(screenSize: screen)
        XCTAssertEqual(viewModel.engine?.state, .idle)
        XCTAssertTrue(viewModel.isAwaitingStart)

        viewModel.beginRun()
        XCTAssertEqual(viewModel.engine?.state, .playing)
        XCTAssertFalse(viewModel.isAwaitingStart)

        viewModel.engine?.update(deltaTime: 0.5)
        viewModel.beginRun()
        XCTAssertGreaterThan(viewModel.engine!.elapsed, 0, "a second beginRun doesn't restart the run")
    }
}
