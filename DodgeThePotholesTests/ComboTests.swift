import XCTest
@testable import DodgeThePotholes

/// The combo rules, and near-miss judging in the engine.
@MainActor
final class ComboTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private let rules = GameTuning.bundled.combo

    /// The car's visual box at the start of a run: x −32…32, y −542…−417.
    private var car: CGRect { makeEngine().player.boundingRect }

    private func makeEngine() -> GameEngine {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        return engine
    }

    /// Drops a `type` past the car's right side, `gap` units clear of it, then lets it pass.
    private func passBy(_ engine: GameEngine, _ type: ObstacleType = .pothole, gap: Double) {
        let car = engine.player.boundingRect
        let size = type.size
        engine.insert(ObstacleEntity(id: UUID(),
                                     position: CGPoint(x: car.maxX + gap + size.width / 2,
                                                       y: car.maxY + 100 + size.height / 2),
                                     size: size, velocity: CGVector(dx: 0, dy: -800), type: type))
        for _ in 0..<60 { engine.update(deltaTime: 1.0 / 60) }
    }

    /// Crashes into a cone placed on the car, costing a life (and the combo).
    private func crash(_ engine: GameEngine) {
        let car = engine.player.collisionRect
        engine.insert(ObstacleEntity(id: UUID(), position: CGPoint(x: car.midX, y: car.midY),
                                     size: ObstacleType.cone.size, velocity: .zero, type: .cone))
        engine.update(deltaTime: 1.0 / 60)
    }

    // MARK: - Combo rules

    func testMultiplierClimbsEveryThreeActionsUpToFive() {
        var combo = Combo(rules: rules)
        XCTAssertEqual(combo.multiplier, 1)
        XCTAssertFalse(combo.add(actions: 2))
        XCTAssertTrue(combo.add(actions: 1), "the third action levels up")
        XCTAssertEqual(combo.multiplier, 2)
        combo.add(actions: 30)
        XCTAssertEqual(combo.multiplier, 5)
    }

    func testComboLapsesAfterTheWindow() {
        var combo = Combo(rules: rules)
        combo.add(actions: 1)
        combo.tick(dt: rules.window - 0.1)
        XCTAssertTrue(combo.isActive)
        combo.add(actions: 1)                  // a new action restarts the timer
        combo.tick(dt: rules.window - 0.1)
        XCTAssertTrue(combo.isActive)
        combo.tick(dt: 0.2)
        XCTAssertFalse(combo.isActive)
        XCTAssertEqual(combo.multiplier, 1)
    }

    // MARK: - Near-misses

    func testCloseCallScoresANearMiss() {
        let engine = makeEngine()
        let before = engine.score
        passBy(engine, gap: rules.nearMissGap - 2)
        XCTAssertEqual(engine.stats.nearMisses, 1)
        XCTAssertEqual(engine.combo.chain, 1)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
        XCTAssertEqual(engine.score - before, 60 + rules.nearMissPoints, "a second of driving plus the bonus")
    }

    func testWideMissScoresNothing() {
        let engine = makeEngine()
        passBy(engine, gap: rules.nearMissGap + 2)
        XCTAssertEqual(engine.stats.nearMisses, 0)
        XCTAssertFalse(engine.combo.isActive)
    }

    func testRoadsideTreesDontCount() {
        let engine = makeEngine()
        passBy(engine, .plant, gap: 4)
        XCTAssertEqual(engine.stats.nearMisses, 0)
    }

    func testNoNearMissesWhileInvincible() {
        let engine = makeEngine()
        crash(engine)
        XCTAssertTrue(engine.player.isRecovering)
        passBy(engine, gap: 4)
        XCTAssertEqual(engine.stats.nearMisses, 0)
    }

    func testDrunkNearMissCountsDouble() {
        let engine = makeEngine()
        engine.activatePowerUp(.booze)
        engine.update(deltaTime: 1.0 / 60)
        XCTAssertTrue(engine.player.isDrunk)
        passBy(engine, gap: 4)
        XCTAssertEqual(engine.combo.chain, rules.drunkNearMissActions)
    }

    func testCrashResetsTheCombo() {
        let engine = makeEngine()
        passBy(engine, gap: 4)
        passBy(engine, gap: 4)
        XCTAssertEqual(engine.combo.chain, 2)
        crash(engine)
        XCTAssertFalse(engine.combo.isActive)
    }

    func testMultiplierBoostsBonusesAndSurvivalPoints() {
        let engine = makeEngine()
        passBy(engine, gap: 4)
        passBy(engine, gap: 4)
        let beforeThird = engine.score
        passBy(engine, gap: 4)                 // third action: x2
        XCTAssertEqual(engine.combo.multiplier, 2)
        XCTAssertEqual(engine.stats.bestMultiplier, 2)
        // Most of that second was at x1, then the bonus was paid at x2.
        XCTAssertGreaterThanOrEqual(engine.score - beforeThird, 60 + 2 * rules.nearMissPoints)

        let before = engine.score
        for _ in 0..<60 { engine.update(deltaTime: 1.0 / 60) }
        XCTAssertEqual(engine.score - before, 120, "survival points are doubled at x2")
    }

    // MARK: - Traffic Zones

    /// A small zone: two cone walls either side of the car, `inset` units from it.
    private func zone(around car: CGRect, inset: Double) -> [ObstacleEntity] {
        let size = ObstacleType.cone.size
        return [-1.0, 1.0].flatMap { side in
            (0..<4).map { row in
                let x = side < 0 ? car.minX - inset - size.width / 2 : car.maxX + inset + size.width / 2
                return ObstacleEntity(id: UUID(), position: CGPoint(x: x, y: car.maxY + 60 + Double(row) * size.height),
                                      size: size, velocity: CGVector(dx: 0, dy: -800), type: .cone)
            }
        }
    }

    func testCleanTrafficZonePaysAZoneBonus() {
        let engine = makeEngine()
        engine.insertZone(zone(around: engine.player.boundingRect, inset: 20))
        var events: [GameEvent] = []
        for _ in 0..<60 {
            engine.update(deltaTime: 1.0 / 60)
            events += engine.frameEvents
        }
        let zonePoints = rules.zonePoints * 2   // its 3 actions take the combo to x2
        XCTAssertEqual(events.filter { if case .bonus(.zone, _, _) = $0 { true } else { false } }.count, 1)
        XCTAssertTrue(events.contains(.bonus(.zone, points: zonePoints, at: engine.player.position)))
        XCTAssertEqual(engine.combo.chain, rules.zoneActions)
        XCTAssertEqual(engine.stats.nearMisses, 0, "cones never count as near-misses")
    }

    func testTouchingAConeSpoilsTheZone() {
        let engine = makeEngine()
        var cones = zone(around: engine.player.boundingRect, inset: 20)
        cones[0].position.x = engine.player.position.x    // one cone in the car's path
        engine.insertZone(cones)
        for _ in 0..<60 { engine.update(deltaTime: 1.0 / 60) }
        XCTAssertFalse(engine.combo.isActive)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start - 1)
    }

    func testMonsterTruckSmashFeedsTheCombo() {
        let engine = makeEngine()
        engine.activatePowerUp(.monsterTruck)
        engine.update(deltaTime: 1.0 / 60)
        crash(engine)                          // the truck smashes the cone instead
        XCTAssertEqual(engine.stats.smashed, 1)
        XCTAssertEqual(engine.combo.chain, 1)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)
    }
}
