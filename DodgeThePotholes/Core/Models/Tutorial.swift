import Foundation

/// The first-run tutorial: four guided steps on a practice road, each placing what it
/// needs in front of the car (again if the player misses it) until they've done it.
struct Tutorial: Equatable {

    enum Step: Int, CaseIterable {
        case steer, honk, coins, powerUp, done
    }

    /// The step on screen.
    private(set) var step: Step = .steer
    /// How the player steers, so the first prompt says the right thing.
    let controls: ControlScheme

    /// Seconds the prompt shows before the step places anything.
    static let readTime: Double = 1.2
    /// How far (world units) to steer each way to finish the first step.
    static let steerReach: Double = 110
    /// Coins to collect to finish the coin step.
    static let coinsNeeded = 5
    /// Things are placed no further than this from the centre, so they land on the road
    /// even when the car is out on the verge.
    static let roadReach: Double = 200

    private var stepTime: Double = 0
    private var leftmost: Double = 0
    private var rightmost: Double = 0
    /// The engine's run stats when the step began, to count what the player did since.
    private var baseline = RunStats()

    init(controls: ControlScheme) {
        self.controls = controls
    }

    /// The instruction for the current step.
    var prompt: String {
        switch step {
        case .steer:   return controls == .tilt ? "TILT THE PHONE LEFT AND RIGHT" : "DRAG LEFT AND RIGHT TO STEER"
        case .honk:    return "TAP THE ROAD TO HONK THE DOG AWAY"
        case .coins:   return "DRIVE THROUGH THE COINS"
        case .powerUp: return "GRAB THE POWER-UP"
        case .done:    return "YOU'RE READY!"
        }
    }

    /// Steps finished, out of the four guided ones.
    var progress: Int { min(step.rawValue, Step.done.rawValue) }

    /// Follows the player's progress and places what the current step needs.
    /// Call after every engine step.
    @MainActor
    mutating func update(engine: GameEngine, dt: Double) {
        stepTime += dt
        let x = engine.player.position.x
        let lane = min(max(x, -Self.roadReach), Self.roadReach)
        let stats = engine.stats

        switch step {
        case .steer:
            leftmost = min(leftmost, x)
            rightmost = max(rightmost, x)
            if leftmost <= -Self.steerReach && rightmost >= Self.steerReach { advance(stats) }

        case .honk:
            if stats.scared > baseline.scared { advance(stats); return }
            let dogOnRoad = engine.obstacles.contains { $0.type == .dog && $0.isCollidable }
            if stepTime >= Self.readTime && !dogOnRoad { engine.place(.dog, atX: lane) }

        case .coins:
            if stats.coins - baseline.coins >= Self.coinsNeeded { advance(stats); return }
            if stepTime >= Self.readTime && engine.coins.isEmpty { engine.placeCoins(8, atX: lane) }

        case .powerUp:
            if stats.powerUps > baseline.powerUps { advance(stats); return }
            if stepTime >= Self.readTime && engine.powerUpEntities.isEmpty { engine.place(.multiplier(2), atX: lane) }

        case .done:
            break
        }
    }

    private mutating func advance(_ stats: RunStats) {
        step = Step(rawValue: step.rawValue + 1) ?? .done
        stepTime = 0
        baseline = stats
    }
}
