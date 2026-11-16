import XCTest
import SpriteKit
@testable import DodgeThePotholes

/// Pickup and horn events from the engine, and the effect nodes drawn for them.
@MainActor
final class PickupEffectsTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)

    private var playerPoint: CGPoint { CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset) }

    private func makeEngine() -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        return engine
    }

    func testCoinEmitsCoinCollected() {
        let engine = makeEngine()
        engine.insert(CoinEntity(id: UUID(), position: playerPoint, size: CGSize(width: 12.5, height: 25), velocity: .zero))
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.frameEvents, [.coinCollected(at: playerPoint)])
    }

    func testPowerUpEmitsPowerUpCollected() {
        let engine = makeEngine()
        engine.activatePowerUp(.wrap)
        engine.update(deltaTime: 0.016)
        XCTAssertEqual(engine.frameEvents, [.powerUpCollected(.wrap, at: playerPoint)])
    }

    func testExtraLifeAtFullLivesEmitsNothing() {
        let engine = makeEngine()
        engine.setLives(GameTuning.bundled.lives.max)
        engine.activatePowerUp(.oneUp)
        engine.update(deltaTime: 0.016)
        XCTAssertTrue(engine.frameEvents.isEmpty)
    }

    func testHornScareEmitsScared() {
        let engine = makeEngine()
        let dogPoint = CGPoint(x: 0, y: playerPoint.y + 200)
        engine.insert(ObstacleEntity(id: UUID(), position: dogPoint, size: ObstacleType.dog.size,
                                     velocity: .zero, type: .dog))
        engine.honk()
        var events: [GameEvent] = []
        for _ in 0..<30 {
            engine.update(deltaTime: 0.016)
            events += engine.frameEvents
        }
        XCTAssertEqual(events, [.scared(at: dogPoint)])
    }

    func testSparksBurstAndCleanUp() {
        let burst = EffectNodes.sparks(at: .zero, color: .yellow, count: 6, size: 8, distance: 40, duration: 0.25)
        XCTAssertEqual(burst.children.count, 6)
        XCTAssertTrue(burst.hasActions(), "removes itself when done")
    }
}
