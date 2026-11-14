import XCTest
@testable import DodgeThePotholes

/// Behavioural tests for `GameEngine`, checked against the legacy game's rules.
@MainActor
final class GameEngineTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private var recorder: RecordingDelegate!

    /// A point inside the player's hit box (front half of the car).
    private var hitPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset + 40) }

    override func setUp() async throws {
        try await super.setUp()
        recorder = RecordingDelegate()
    }

    // MARK: - Speed model

    func testObstaclesSpawnEvery1_75sWhileTravelTimeRamps() {
        let engine = makeEngine(tables: SpawnTables(obstacles: [(.single(.plant), 1)],
                                                    environment: [], powerUps: []))
        step(engine, 3.6)
        XCTAssertEqual(engine.obstacles.count, 2, "spawns at 1.75 s and 3.5 s")
        XCTAssertEqual(engine.travelDuration, 2.0)

        step(engine, 7.0)   // t = 10.6
        XCTAssertEqual(engine.travelDuration, 1.9, accuracy: 1e-9)
        let plant = try! XCTUnwrap(engine.obstacles.last)
        let distance = world.height / 2 + plant.size.height / 2 + world.height / 2 + plant.size.height
        XCTAssertEqual(plant.velocity.dy, -distance / 1.9, accuracy: 1e-6,
                       "new obstacles use the ramped travel time")
    }

    // MARK: - Coins & money

    func testCoinPatternSpawnsCoinsAboveTheScreen() {
        let engine = makeEngine(tables: SpawnTables(obstacles: [], environment: [(.coinPattern, 1)], powerUps: []))
        step(engine, 1.05)
        XCTAssertFalse(engine.coins.isEmpty)
        XCTAssertTrue(engine.coins.allSatisfy { $0.position.y > world.height / 2 })
    }

    func testCollectingCoinsAddsMoneyWithMultiplier() {
        let engine = makeEngine()
        engine.insert(coin(at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.money, 1)

        engine.insert(powerUp(.multiplier(3), at: hitPoint))
        engine.update(deltaTime: 0.016)
        engine.insert(coin(at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.money, 4)
        XCTAssertTrue(recorder.sounds.contains(.money))
    }

    // MARK: - Obstacle collisions

    func testPhoneCostsNoLifeAndAdvancesLyric() {
        let engine = makeEngine()
        engine.insert(obstacle(.textMessage, at: hitPoint))
        engine.update(deltaTime: 0.016)
        engine.insert(obstacle(.textMessage, at: hitPoint))
        engine.update(deltaTime: 0.016)

        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
        XCTAssertEqual(recorder.lyricIndices, [0, 1])
        XCTAssertTrue(recorder.sounds.contains(.textTone))
        XCTAssertFalse(recorder.sounds.contains(.crash))
    }

    func testPotholeSpinsOutAndRecoveryLasts4_8sAndPausesWithGame() {
        let engine = makeEngine()
        engine.insert(obstacle(.pothole, at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.player.lives, 2)
        XCTAssertEqual(engine.frameEvents, [.spinOut])
        XCTAssertTrue(recorder.sounds.contains(.carSkid))
        XCTAssertTrue(engine.player.isRecovering)

        // A second pothole rolling through while recovering is ignored.
        engine.insert(obstacle(.pothole, at: hitPoint, speed: 2_000))
        step(engine, 4.7)
        XCTAssertEqual(engine.player.lives, 2)
        XCTAssertTrue(engine.player.isRecovering)

        engine.pause()
        engine.update(deltaTime: 0.05)   // ignored while paused
        engine.resume()
        XCTAssertTrue(engine.player.isRecovering, "recovery clock stops while paused")
        step(engine, 0.15)
        XCTAssertFalse(engine.player.isRecovering)
    }

    func testHittingDogPlaysDeathAndCostsLife() {
        let engine = makeEngine()
        engine.insert(obstacle(.dog, at: hitPoint))
        engine.update(deltaTime: 0.016)

        XCTAssertEqual(engine.player.lives, 2)
        XCTAssertEqual(engine.obstacles.first?.phase, .dying, "dog stays on screen for its death animation")
        XCTAssertTrue(recorder.sounds.contains(.dogWhimper))
    }

    // MARK: - Power-ups

    func testMonsterTruckDestroysObstaclesThenExpires() {
        let engine = makeEngine()
        engine.insert(powerUp(.monsterTruck, at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertTrue(engine.player.isMonsterTruck)
        XCTAssertEqual(engine.player.size, GameConfig.monsterTruckSize)

        engine.insert(obstacle(.pothole, at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
        XCTAssertTrue(engine.obstacles.isEmpty)
        XCTAssertEqual(engine.frameEvents.count, 1)
        XCTAssertTrue(recorder.sounds.contains(.explosion))

        step(engine, GameTuning.bundled.durations.monsterTruck)
        XCTAssertFalse(engine.player.isMonsterTruck)
        XCTAssertEqual(engine.player.size, GameConfig.playerSize)
    }

    func testBoozeInvertsSteeringAndRaisesAlert() {
        let engine = makeEngine()
        engine.insert(powerUp(.booze, at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertTrue(engine.player.isDrunk)
        XCTAssertEqual(recorder.alerts, [.dontDrinkAndDrive])

        engine.setHorizontalInput(1)
        engine.update(deltaTime: 0.1)
        XCTAssertLessThan(engine.player.position.x, 0, "steering right moves left while drunk")
    }

    func testRecoveringPlayerIgnoresBooze() {
        let engine = makeEngine()
        engine.insert(obstacle(.pothole, at: hitPoint))
        engine.update(deltaTime: 0.016)
        engine.insert(powerUp(.booze, at: hitPoint))
        engine.update(deltaTime: 0.016)
        XCTAssertFalse(engine.player.isDrunk)
    }

    func testWrapLetsPlayerCrossTheEdge() {
        let engine = makeEngine()
        engine.setHorizontalInput(1)
        step(engine, 1)
        XCTAssertLessThan(engine.player.position.x, world.width / 2, "clamped without wrap")
        XCTAssertGreaterThan(engine.player.position.x, 0)

        engine.insert(powerUp(.wrap, at: engine.player.position))
        step(engine, 0.3)
        XCTAssertLessThan(engine.player.position.x, 0, "re-entered from the left edge")
    }

    // MARK: - Spawning

    func testConePatternAlertsAndPausesObstacleSpawner() {
        let engine = makeEngine(tables: SpawnTables(obstacles: [(.conePattern, 1)], environment: [], powerUps: []))
        step(engine, 1.8)
        XCTAssertEqual(recorder.alerts, [.trafficZone])
        XCTAssertFalse(engine.obstacles.isEmpty)
        XCTAssertTrue(engine.obstacles.allSatisfy { $0.type == .cone || $0.type == .barricade })

        step(engine, 18)
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(recorder.alerts.count, 1, "spawner paused for 25 s after a traffic zone")
    }

    // MARK: - Horn

    func testHornScaresDogAway() {
        let engine = makeEngine()
        let dogY = engine.player.position.y + 200
        engine.insert(obstacle(.dog, at: CGPoint(x: 0, y: dogY)))
        engine.honk()
        XCTAssertEqual(engine.horns.count, 1)
        XCTAssertTrue(recorder.sounds.contains(.carHonk))

        step(engine, 0.5)
        let dog = try! XCTUnwrap(engine.obstacles.first)
        XCTAssertEqual(dog.phase, .fleeing)
        XCTAssertEqual(dog.facing, -1)
        XCTAssertTrue(engine.horns.isEmpty, "horn is used up by the hit")
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
    }

    // MARK: - Seeded runs

    func testSameSeedSpawnsSameRoad() {
        XCTAssertEqual(spawnedRoad(seed: 7, fps: 60), spawnedRoad(seed: 7, fps: 60))
        XCTAssertNotEqual(spawnedRoad(seed: 7, fps: 60), spawnedRoad(seed: 8, fps: 60))
    }

    func testSeededRoadDoesNotDependOnFrameRate() {
        for seed: UInt64 in 1...20 {
            XCTAssertEqual(spawnedRoad(seed: seed, fps: 60), spawnedRoad(seed: seed, fps: 120), "seed \(seed)")
        }
    }

    // MARK: - Helpers

    /// Every plant spawned in the first 29.5 s of a seeded run, as sorted "variant@x" strings.
    /// Plants sit on the road side, so the idle player never hits one.
    private func spawnedRoad(seed: UInt64, fps: Double) -> [String] {
        let tables = SpawnTables(obstacles: [(.single(.plant), 1)], environment: [(.plant, 1)], powerUps: [])
        let engine = GameEngine(worldSize: world, tables: tables, rng: SplitMix64(seed: seed), drivesOwnLoop: false)
        engine.start()
        var seen: [UUID: String] = [:]
        for _ in 0..<Int(29.5 * fps) {
            engine.update(deltaTime: 1 / fps)
            for plant in engine.obstacles where seen[plant.id] == nil {
                seen[plant.id] = "\(plant.variant)@\(plant.position.x)"
            }
        }
        return seen.values.sorted()
    }

    private func makeEngine(tables: SpawnTables = .none) -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: tables,
                                rng: SplitMix64(seed: 42), drivesOwnLoop: false)
        engine.delegate = recorder
        engine.start()
        return engine
    }

    /// Advances the engine in 50 ms frames.
    private func step(_ engine: GameEngine, _ seconds: Double) {
        let frames = Int((seconds / 0.05).rounded())
        for _ in 0..<frames { engine.update(deltaTime: 0.05) }
    }

    /// An obstacle at `position`, optionally falling at `speed` world units per second.
    private func obstacle(_ type: ObstacleType, at position: CGPoint, speed: Double = 0) -> ObstacleEntity {
        ObstacleEntity(id: UUID(), position: position, size: type.size, velocity: CGVector(dx: 0, dy: -speed), type: type)
    }

    private func powerUp(_ type: PowerUpType, at position: CGPoint) -> PowerUpEntity {
        PowerUpEntity(id: UUID(), position: position, size: type.spawnSize, velocity: CGVector(dx: 0, dy: 0), type: type)
    }

    private func coin(at position: CGPoint) -> CoinEntity {
        CoinEntity(id: UUID(), position: position, size: CGSize(width: 12.5, height: 25), velocity: CGVector(dx: 0, dy: 0))
    }
}

// MARK: - Test doubles

/// Records every delegate callback for assertions.
@MainActor
final class RecordingDelegate: GameEngineDelegate {
    var sounds: [GameSound] = []
    var alerts: [GameAlert] = []
    var lyricIndices: [Int] = []
    var lives: [Int] = []
    var didEnd = false

    func engine(_ engine: GameEngine, didUpdateScore score: Int) {}
    func engine(_ engine: GameEngine, didUpdateMoney money: Int) {}
    func engine(_ engine: GameEngine, didUpdateLives lives: Int) { self.lives.append(lives) }
    func engine(_ engine: GameEngine, didChangePlayerState state: PlayerState) {}
    func engine(_ engine: GameEngine, didActivatePowerUp powerUp: PowerUpState) {}
    func engine(_ engine: GameEngine, didDeactivatePowerUp type: PowerUpType) {}
    func engine(_ engine: GameEngine, didTriggerTextMessageAt index: Int) { lyricIndices.append(index) }
    func engine(_ engine: GameEngine, didRaiseAlert alert: GameAlert) { alerts.append(alert) }
    func engineDidEnd(_ engine: GameEngine, finalScore: Int, moneyEarned: Int) { didEnd = true }
    func engine(_ engine: GameEngine, requestsSound sound: GameSound) { sounds.append(sound) }
    func engine(_ engine: GameEngine, requestsHaptic pattern: HapticPattern) {}
}
