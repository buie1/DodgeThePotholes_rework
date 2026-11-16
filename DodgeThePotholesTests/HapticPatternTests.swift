import XCTest
@testable import DodgeThePotholes

/// Which haptic the engine asks for on each event, and the coin-tick throttle.
@MainActor
final class HapticPatternTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private var recorder: RecordingDelegate!

    private var hitPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset + 40) }

    override func setUp() async throws {
        try await super.setUp()
        recorder = RecordingDelegate()
    }

    private func makeEngine() -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.delegate = recorder
        engine.start()
        return engine
    }

    private func hit(_ type: ObstacleType, _ engine: GameEngine) {
        engine.insert(ObstacleEntity(id: UUID(), position: hitPoint, size: type.size, velocity: .zero, type: type))
        engine.update(deltaTime: 0.016)
    }

    func testCrashAndSpinOutFeelDifferent() {
        hit(.ambulance, makeEngine())
        hit(.blackIce, makeEngine())
        XCTAssertEqual(recorder.haptics, [.crash, .spinOut])
    }

    func testMonsterTruckSmashIsAnExplosionNotACrash() {
        let engine = makeEngine()
        engine.activatePowerUp(.monsterTruck)
        engine.update(deltaTime: 0.016)
        recorder.haptics.removeAll()
        hit(.policeCar, engine)
        XCTAssertEqual(recorder.haptics, [.explosion])
    }

    func testLastLifeAddsGameOver() {
        let engine = makeEngine()
        engine.setLives(1)
        hit(.cone, engine)
        XCTAssertEqual(recorder.haptics, [.crash, .gameOver])
    }

    func testHornScareTaps() {
        let engine = makeEngine()
        engine.insert(ObstacleEntity(id: UUID(), position: CGPoint(x: 0, y: hitPoint.y + 160),
                                     size: ObstacleType.human.size, velocity: .zero, type: .human))
        engine.honk()
        for _ in 0..<30 { engine.update(deltaTime: 0.016) }
        XCTAssertEqual(recorder.haptics, [.hornScare])
    }

    func testNearMissTicksAndTheThirdLevelsUp() {
        let engine = makeEngine()
        let car = engine.player.boundingRect
        for _ in 0..<3 {
            engine.insert(ObstacleEntity(id: UUID(), position: CGPoint(x: car.maxX + 10 + 33, y: car.maxY + 140),
                                         size: ObstacleType.pothole.size, velocity: CGVector(dx: 0, dy: -800),
                                         type: .pothole))
            for _ in 0..<60 { engine.update(deltaTime: 1.0 / 60) }
        }
        XCTAssertEqual(recorder.haptics, [.nearMiss, .nearMiss, .comboLevelUp])
    }

    func testThrottleSpacesCoinTicksButNothingElse() {
        var throttle = HapticThrottle()
        XCTAssertTrue(throttle.allows(.coinPickup, at: 1.00))
        XCTAssertFalse(throttle.allows(.coinPickup, at: 1.03))
        XCTAssertTrue(throttle.allows(.crash, at: 1.03), "impacts are never throttled")
        XCTAssertTrue(throttle.allows(.coinPickup, at: 1.08))
        XCTAssertTrue(throttle.allows(.nearMiss, at: 1.08), "each tick kind is spaced separately")
        XCTAssertFalse(throttle.allows(.nearMiss, at: 1.10))
    }
}
