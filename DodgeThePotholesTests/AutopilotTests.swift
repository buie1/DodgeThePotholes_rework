import XCTest
@testable import DodgeThePotholes

/// The dev-mode autopilot and headless scenario runs.
@MainActor
final class AutopilotTests: XCTestCase {

    private let world = CGSize(width: 750, height: 1334)
    private let pilot = Autopilot()

    private var player: PlayerEntity {
        PlayerEntity(position: CGPoint(x: 0, y: -world.height / 2 + GameConfig.playerBottomOffset),
                     velocity: .zero, size: GameConfig.playerSize, carSkin: .blue, lives: 3)
    }

    /// An obstacle `ahead` units in front of the player, falling at 667 units/s.
    private func oncoming(_ type: ObstacleType, x: Double = 0, ahead: Double = 300) -> ObstacleEntity {
        ObstacleEntity(id: UUID(), position: CGPoint(x: x, y: player.position.y + ahead),
                       size: type.size, velocity: CGVector(dx: 0, dy: -667), type: type)
    }

    func testHoldsCourseOnAnEmptyRoad() {
        let decision = pilot.decide(player: player, obstacles: [], worldWidth: world.width)
        XCTAssertEqual(decision, Autopilot.Decision(input: 0, honk: false))
    }

    func testSteersAroundAPotholeAhead() {
        let decision = pilot.decide(player: player, obstacles: [oncoming(.pothole)], worldWidth: world.width)
        XCTAssertNotEqual(decision.input, 0)
        XCTAssertFalse(decision.honk)
    }

    func testHonksAtADogAhead() {
        let decision = pilot.decide(player: player, obstacles: [oncoming(.dog)], worldWidth: world.width)
        XCTAssertTrue(decision.honk)
    }

    func testIgnoresObstaclesBeyondItsLookahead() {
        let far = oncoming(.pothole, ahead: 667 * 3)
        XCTAssertEqual(pilot.decide(player: player, obstacles: [far], worldWidth: world.width).input, 0)
    }

    func testCountersDrunkSteering() {
        var drunk = player
        drunk.isDrunk = true
        let sober = pilot.decide(player: player, obstacles: [oncoming(.pothole, x: 20)], worldWidth: world.width)
        let tipsy = pilot.decide(player: drunk, obstacles: [oncoming(.pothole, x: 20)], worldWidth: world.width)
        XCTAssertEqual(tipsy.input, -sober.input)
    }

    // MARK: - Headless runs

    func testElapsedCountsPlayTime() {
        let summary = ScenarioRunner.run(DevScenario(seed: 1, godMode: true), seconds: 10)
        XCTAssertEqual(summary.elapsed, 10, accuracy: 0.05)
        XCTAssertEqual(summary.livesLost, 0)
    }

    func testAutopilotLosesFewerLivesThanAnIdleDriver() {
        var idleLosses = 0, pilotLosses = 0
        for seed: UInt64 in 1...5 {
            idleLosses += ScenarioRunner.run(DevScenario(seed: seed), seconds: 60).livesLost
            pilotLosses += ScenarioRunner.run(DevScenario(seed: seed, autopilot: true), seconds: 60).livesLost
        }
        XCTAssertLessThan(pilotLosses, idleLosses, "autopilot \(pilotLosses) vs idle \(idleLosses)")
    }
}
