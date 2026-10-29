import Foundation

/// Central configuration for all game constants.
/// Replaces the scattered global `let` values in legacy GlobalConstants.swift.
enum GameConfig {

    // MARK: - World / Layout
    /// Fraction of world width used as the player lane boundary.
    static let laneHalfWidthFraction: Double = 0.45

    // MARK: - Player
    static let playerSize          = CGSize(width: 64, height: 125)
    static let monsterTruckSize    = CGSize(width: 300, height: 301)
    /// Maximum lateral speed in points per second.
    static let playerMaxSpeed: Double = 420
    /// Bottom margin above the world edge where the player sits.
    static let playerBottomMargin: Double = 80

    // MARK: - Lives
    static let beginningLifeCount: Int = 3
    static let maxLifeCount: Int       = 4

    // MARK: - Scoring
    /// Score points awarded per second of survival.
    static let scoreRatePerSecond: Double = 60

    // MARK: - Speed ramp
    /// Starting movement duration (seconds to cross full screen height).
    static let startObstacleInterval: Double = 2.0
    /// Minimum obstacle interval (fastest the game ever gets).
    static let minObstacleInterval: Double   = 0.2
    /// How often (seconds) the speed steps down.
    static let speedRampInterval: Double     = 10.0
    /// How much the interval decreases each ramp step.
    static let speedRampStep: Double         = 0.1

    // MARK: - Spawn intervals (seconds between spawns)
    static let obstacleSpawnInterval: Double  = 1.75
    static let environmentSpawnInterval: Double = 1.0
    static let powerUpSpawnInterval: Double   = 5.0

    // MARK: - Obstacle sizes (points)
    static let potholeSize      = CGSize(width: 66,    height: 65)
    static let blackIceSize     = CGSize(width: 66,    height: 65)
    static let coneSize         = CGSize(width: 20,    height: 20)
    static let barricadeSize    = CGSize(width: 40,    height: 40)
    static let plantSize        = CGSize(width: 101,   height: 100)
    static let phoneSize        = CGSize(width: 40,    height: 80)
    static let movingCarSize    = CGSize(width: 62.5,  height: 125)
    static let ambulanceSize    = CGSize(width: 62.5,  height: 125)
    static let policeCarSize    = CGSize(width: 62.5,  height: 125)
    static let dogSize          = CGSize(width: 51,    height: 50)
    static let humanSize        = CGSize(width: 40,    height: 80)

    // MARK: - Collectible / power-up sizes
    static let coinTileSize     = CGSize(width: 25,    height: 50)
    static let coneTileSize     = CGSize(width: 40,    height: 40)
    static let powerUpSize      = CGSize(width: 50,    height: 51)

    // MARK: - Spawn X ranges (fraction of world half-width)
    /// Potholes and black ice spawn in this fraction of half-width.
    static let centralSpawnHalfFraction: Double = 0.25
    /// Phone (TextMessage) spawn fraction.
    static let phoneSpawnHalfFraction: Double   = 0.40
    /// Plants spawn at this fixed fraction (side of road).
    static let plantSpawnFraction: Double       = 0.4375

    // MARK: - Powerup durations (seconds)
    static let wrapDuration: Double         = 15
    static let multiplierDuration: Double   = 30
    static let monsterTruckDuration: Double = 18
    static let boozeDuration: Double        = 15

    // MARK: - Recovery (post-collision invincibility, seconds)
    static let recoveryDuration: Double = 2.5

    // MARK: - Shop costs
    // Note: car and song intentionally share the same price (500),
    // so this is a namespace enum with static constants rather than
    // a raw-value enum (which requires unique values).
    enum ShopCost {
        static let car:  Int = 500
        static let life: Int = 1_000
        static let tank: Int = 5_000
        static let song: Int = 500
    }

    // MARK: - Text messages (rickroll easter egg)
    static let maxTextMessageIndex: Int = 57

    // MARK: - Obstacle spawn weights
    /// Weighted pool mirroring the legacy `possibleObstacles` array.
    static let obstacleWeights: [(ObstacleType, Int)] = [
        (.pothole,     4),
        (.movingCar,   3),
        (.blackIce,    3),
        (.ambulance,   2),
        (.policeCar,   2),
        (.textMessage, 1),
        (.dog,         1),
        (.human,       1),
    ]

    /// Environment obstacle weights (90 % plant, 10 % coin pattern).
    static let envWeights: [(EnvSpawnType, Int)] = [
        (.plant,       9),
        (.coinPattern, 1),
    ]
}

/// Discriminates environment-only spawn events (not physics obstacles).
enum EnvSpawnType {
    case plant
    case coinPattern
}
