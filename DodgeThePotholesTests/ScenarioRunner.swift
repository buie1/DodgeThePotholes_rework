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
    }

    static func run(_ scenario: DevScenario, seconds: Double, fps: Double = 60,
                    world: CGSize = CGSize(width: 750, height: 1334)) -> Summary {
        let (engine, _) = scenario.makeEngine(worldSize: world)
        let recorder = RecordingDelegate()
        engine.delegate = recorder
        engine.start()
        scenario.apply(to: engine)
        let startLives = engine.player.lives
        recorder.lives.removeAll()

        for _ in 0..<Int(seconds * fps) where engine.state == .playing {
            engine.update(deltaTime: 1 / fps)
        }
        let lives = [startLives] + recorder.lives
        let livesLost = zip(lives, lives.dropFirst()).filter { $1 < $0 }.count
        return Summary(elapsed: engine.elapsed, score: engine.score, money: engine.money,
                       livesLost: livesLost, isGameOver: engine.state == .gameOver)
    }
}
