import Foundation
import CoreGraphics

/// One-shot visual effects emitted by `GameEngine` during a single `update`.
/// The renderer reads `GameEngine.frameEvents` right after each update.
enum GameEvent: Equatable {
    /// The player hit a pothole or black ice and spins out.
    case spinOut
    /// The player crashed into an obstacle at this point and loses a life.
    case crash(at: CGPoint)
    /// An obstacle was destroyed by the monster truck, or a missile detonated.
    case explosion(at: CGPoint)
    /// A coin was collected here.
    case coinCollected(at: CGPoint)
    /// A power-up took effect when picked up here (an extra life at full lives doesn't).
    case powerUpCollected(PowerUpType, at: CGPoint)
    /// The horn scared a dog or person off the road from here.
    case scared(at: CGPoint)
}

/// Banner messages the UI flies across the screen.
enum GameAlert: Equatable {
    /// A cone pattern is coming ("Traffic Zone Approaching!").
    case trafficZone
    /// The player picked up booze ("Don't Drink and Drive!").
    case dontDrinkAndDrive

    var message: String {
        switch self {
        case .trafficZone:       return "Traffic Zone Approaching!"
        case .dontDrinkAndDrive: return "Don't Drink and Drive!"
        }
    }
}

/// The weighted pools the engine rolls on each spawn tick.
/// Injectable so tests can force specific spawns.
struct SpawnTables {
    var obstacles: [(ObstacleSpawn, Int)]
    var environment: [(EnvSpawnType, Int)]
    var powerUps: [(PowerUpSpawn, Int)]

    /// The pools from the bundled `tuning.json`.
    static var standard: SpawnTables { GameTuning.bundled.weights }

    /// Spawns nothing. Useful for tests that place entities by hand.
    static let none = SpawnTables(obstacles: [], environment: [], powerUps: [])
}
