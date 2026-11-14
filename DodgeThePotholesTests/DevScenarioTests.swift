import XCTest
@testable import DodgeThePotholes

/// Dev-mode scenarios and the engine's debug hooks.
@MainActor
final class DevScenarioTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private let screen = CGSize(width: 402, height: 874)

    /// A point inside the player's hit box (front half of the car).
    private var hitPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset + 40) }

    // MARK: - Scenarios

    func testPresetsAreNamedUniquely() {
        let names = DevScenario.presets.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertNotNil(DevScenario.preset(named: "monsterTruck"))
    }

    func testLaunchArgumentsPickPresetOrJSON() throws {
        XCTAssertNil(try DevScenario.fromLaunchArguments(["app"]))
        XCTAssertEqual(try DevScenario.fromLaunchArguments(["app", "-devScenario", "lateGame"])?.startElapsed, 170)

        let json = #"{"seed": 7, "godMode": true, "obstacles": [{"spawn": "dog", "weight": 1}], "startPowerUps": ["x2"]}"#
        let scenario = try XCTUnwrap(try DevScenario.fromLaunchArguments(["app", "-devScenarioJSON", json]))
        XCTAssertEqual(scenario.seed, 7)
        XCTAssertTrue(scenario.godMode)
        XCTAssertEqual(scenario.startPowerUps, [.multiplier(2)])

        let tables = scenario.spawnTables(base: GameTuning.bundled.weights)
        XCTAssertEqual(tables.obstacles.map(\.0), [.single(.dog)])
        XCTAssertEqual(tables.powerUps.count, GameTuning.bundled.weights.powerUps.count, "unset pools keep the tuning's")
    }

    func testBadLaunchArgumentsThrow() {
        XCTAssertThrowsError(try DevScenario.fromLaunchArguments(["app", "-devScenario", "nope"]))
        XCTAssertThrowsError(try DevScenario.fromLaunchArguments(["app", "-devScenario"]))
        XCTAssertThrowsError(try DevScenario.fromLaunchArguments(["app", "-devScenarioJSON", #"{"startPowerUps": ["jetpack"]}"#]))
        XCTAssertThrowsError(try DevScenario.fromLaunchArguments(["app", "-devScenarioJSON", #"{"obstacles": [{"spawn": "meteor", "weight": 1}]}"#]))
    }

    // MARK: - Engine hooks

    func testGodModeHitCostsNoLife() {
        let engine = makeEngine()
        engine.debug.godMode = true
        engine.insert(ObstacleEntity(id: UUID(), position: hitPoint, size: ObstacleType.pothole.size,
                                     velocity: .zero, type: .pothole))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
        XCTAssertTrue(engine.player.isRecovering, "the hit still flashes the car")
    }

    func testTimeScaleSpeedsUpTheClock() {
        let normal = makeEngine(), fast = makeEngine()
        fast.debug.timeScale = 2
        for _ in 0..<60 {
            normal.update(deltaTime: 1.0 / 60)
            fast.update(deltaTime: 1.0 / 60)
        }
        XCTAssertEqual(normal.score, 60)
        XCTAssertEqual(fast.score, 120)
    }

    func testSpawnNowAndActivatePowerUp() {
        let engine = makeEngine()
        engine.spawnNow(ObstacleSpawn.single(.ambulance))
        engine.spawnNow(PowerUpSpawn.phone)
        XCTAssertEqual(engine.obstacles.map(\.type), [.ambulance, .textMessage])

        engine.activatePowerUp(.monsterTruck)
        engine.update(deltaTime: 0.016)
        XCTAssertTrue(engine.player.isMonsterTruck)
    }

    func testFastForwardAndLives() {
        let engine = makeEngine()
        engine.fastForwardSpeedRamp(by: 170)   // 17 ramp steps
        XCTAssertEqual(engine.travelDuration, 0.3, accuracy: 1e-9)
        engine.fastForwardSpeedRamp(by: 1_000)
        XCTAssertEqual(engine.travelDuration, GameTuning.bundled.speed.minTravelDuration)
        engine.setLives(9)
        XCTAssertEqual(engine.player.lives, 9)
    }

    // MARK: - View model

    func testDevRunAppliesScenarioAndNeverSubmits() async {
        let persistence = MockPersistenceService()
        let leaderboard = MockLeaderboardService()
        let viewModel = makeViewModel(persistence: persistence, leaderboard: leaderboard)
        viewModel.devScenario = DevScenario(seed: 1, startPowerUps: [.monsterTruck], lives: 1, godMode: true)

        viewModel.startGame(screenSize: screen)
        let engine = try! XCTUnwrap(viewModel.engine)
        XCTAssertTrue(engine.debug.godMode)
        XCTAssertEqual(engine.player.lives, 1)

        viewModel.engineDidEnd(engine, finalScore: 500, moneyEarned: 20)
        await Task.yield()
        XCTAssertEqual(persistence.runs.count, 1, "the throwaway profile records the run")
        XCTAssertTrue(leaderboard.submittedScores.isEmpty)
    }

    func testDevRunOnRealProfileRecordsNothing() {
        let persistence = MockPersistenceService()
        let viewModel = makeViewModel(persistence: persistence, leaderboard: MockLeaderboardService())
        viewModel.devScenario = DevScenario(useRealProfile: true)

        viewModel.startGame(screenSize: screen)
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 9_999, moneyEarned: 100)
        XCTAssertTrue(persistence.runs.isEmpty)
        XCTAssertEqual(persistence.highScore, 0)
        XCTAssertFalse(viewModel.isNewHighScore)
    }

    func testThrowawayProfileGetsBankAndUnlocks() {
        let store = SwiftDataPersistenceService.inMemory(defaults: UserDefaults(suiteName: "dev-scenario-tests")!)
        store.applyDevSetup(DevScenario(bank: 12_345, unlockAll: true))
        XCTAssertEqual(store.money, 12_345)
        XCTAssertTrue(store.hasTank)
        XCTAssertTrue(store.isUnlocked(CarSkin.green))
        XCTAssertFalse(store.extraLifePending, "the consumable extra life isn't an unlock")
    }

    // MARK: - Helpers

    private func makeEngine() -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        return engine
    }

    private func makeViewModel(persistence: MockPersistenceService,
                               leaderboard: MockLeaderboardService) -> GameViewModel {
        GameViewModel(persistence: persistence, audio: MockAudioService(), haptics: MockHapticService(),
                      motion: MockMotionService(), leaderboard: leaderboard)
    }
}
