import XCTest
@testable import DodgeThePotholes

/// Keeps the bundled combo tuning in its intended range, measured with two stand-in
/// drivers over several seeds. Measured 2026-11-15 (20 seeds × 120 s, god mode):
///   - cautious autopilot: 6.7 near-misses/min, average x1.11
///   - combo-chasing autopilot: 19.3 near-misses/min, average x2.10, 13% of time at x5
/// A careful player should sit near x1, a combo-chaser around x2, and x5 should stay a
/// highlight. If a tuning change trips this, rerun the measurement and decide on purpose.
@MainActor
final class ComboBalanceTests: XCTestCase {

    private func averages(pilot: Autopilot) -> (nearMissesPerMinute: Double, multiplier: Double, timeAtMax: Double) {
        let seeds: [UInt64] = [1, 2, 3, 4, 5, 6]
        var nearMisses = 0.0, multiplier = 0.0, timeAtMax = 0.0
        for seed in seeds {
            let run = ScenarioRunner.run(DevScenario(seed: seed, godMode: true), seconds: 60, pilot: pilot)
            nearMisses += Double(run.stats.nearMisses)
            multiplier += run.averageMultiplier
            timeAtMax += (run.secondsAtMultiplier[GameTuning.bundled.combo.maxMultiplier] ?? 0) / 60
        }
        let n = Double(seeds.count)
        return (nearMisses / n, multiplier / n, timeAtMax / n)
    }

    func testCarefulDrivingRarelyBuildsACombo() {
        let careful = averages(pilot: Autopilot())
        XCTAssertLessThan(careful.multiplier, 1.4, "careful play stays near x1")
    }

    func testChasingNearMissesBuildsARealCombo() {
        let chaser = averages(pilot: .comboChaser)
        XCTAssertGreaterThan(chaser.nearMissesPerMinute, 10)
        XCTAssertGreaterThan(chaser.multiplier, 1.6, "chasing close calls pays off")
        XCTAssertLessThan(chaser.multiplier, 3.0, "but x5 isn't the norm")
        XCTAssertLessThan(chaser.timeAtMax, 0.3, "x5 stays a highlight")
    }
}
