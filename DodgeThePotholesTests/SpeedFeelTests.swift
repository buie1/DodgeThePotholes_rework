import XCTest
import SpriteKit
@testable import DodgeThePotholes

/// The speed ramp's progress and the streaks that show it.
@MainActor
final class SpeedFeelTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)

    func testSpeedProgressRunsFromZeroToOne() {
        let engine = GameEngine(worldSize: world, tables: .none, rng: SplitMix64(seed: 1), drivesOwnLoop: false)
        engine.start()
        XCTAssertEqual(engine.speedProgress, 0)
        engine.fastForwardSpeedRamp(by: 90)   // 9 of 18 ramp steps
        XCTAssertEqual(engine.speedProgress, 0.5, accuracy: 1e-9)
        engine.fastForwardSpeedRamp(by: 1_000)
        XCTAssertEqual(engine.speedProgress, 1)
    }

    func testNoStreaksAtTheStartingSpeed() {
        let lines = SpeedLines(worldSize: world)
        for _ in 0..<60 { lines.update(dt: 1.0 / 60, intensity: 0, roadSpeed: 667) }
        XCTAssertTrue(lines.children.isEmpty)
    }

    func testStreaksBuildWithSpeedAndClearOffScreen() {
        let lines = SpeedLines(worldSize: world)
        // A slow road keeps every streak on screen, so this counts the spawn rate.
        for _ in 0..<30 { lines.update(dt: 1.0 / 60, intensity: 1, roadSpeed: 50) }
        XCTAssertEqual(lines.children.count, 22, accuracy: 1, "45 per second at full intensity")

        for _ in 0..<120 { lines.update(dt: 1.0 / 60, intensity: 0, roadSpeed: 6_670) }
        XCTAssertTrue(lines.children.isEmpty, "streaks leave the screen and are removed")
    }
}
