import CoreGraphics
@testable import DodgeThePotholes

/// Runs a dev scenario headless at a fixed frame rate and sums up the run.
/// The base for balance checks (e.g. "the autopilot survives a minute at seed N").
@MainActor
enum ScenarioRunner {

    struct Summary {
        /// Seconds of play before game over, or the full duration.
        let elapsed: Double
        let score: Int
        let money: Int
        let livesLost: Int
        let isGameOver: Bool
        let stats: RunStats
        /// Clean Traffic Zones paid out.
        let zonesCleared: Int
        /// Seconds spent at each combo multiplier.
        let secondsAtMultiplier: [Int: Double]

        /// Average multiplier over the run, weighted by time.
        var averageMultiplier: Double {
            let total = secondsAtMultiplier.values.reduce(0, +)
            guard total > 0 else { return 1 }
            return secondsAtMultiplier.reduce(0) { $0 + Double($1.key) * $1.value } / total
        }
    }

    /// - Parameter pilot: Drives instead of the scenario's own autopilot setting, e.g. a
    ///   riskier `Autopilot(margin:)` standing in for a player chasing near-misses.
    static func run(_ scenario: DevScenario, seconds: Double, fps: Double = 60, pilot: Autopilot? = nil,
                    world: CGSize = CGSize(width: 750, height: 1334)) -> Summary {
        let (engine, _) = scenario.makeEngine(worldSize: world)
        let recorder = RecordingDelegate()
        engine.delegate = recorder
        engine.start()
        scenario.apply(to: engine)
        if let pilot { engine.debug.autopilot = pilot }
        let startLives = engine.player.lives
        recorder.lives.removeAll()

        var secondsAtMultiplier: [Int: Double] = [:]
        for _ in 0..<Int(seconds * fps) where engine.state == .playing {
            engine.update(deltaTime: 1 / fps)
            secondsAtMultiplier[engine.combo.multiplier, default: 0] += 1 / fps
        }
        let lives = [startLives] + recorder.lives
        let livesLost = zip(lives, lives.dropFirst()).filter { $1 < $0 }.count
        return Summary(elapsed: engine.elapsed, score: engine.score, money: engine.money,
                       livesLost: livesLost, isGameOver: engine.state == .gameOver, stats: engine.stats,
                       zonesCleared: recorder.bonuses.filter { $0 == .zone }.count,
                       secondsAtMultiplier: secondsAtMultiplier)
    }
}
