import Foundation

/// Central configuration for all game constants.
/// Replaces the scattered global `let` values in legacy GlobalConstants.swift.
///
/// All sizes and positions are in **world units**. The legacy game ran in a
/// fixed 750 × 1334 scene, so the world is always 750 units wide and as tall
/// as the screen's aspect ratio requires.
enum GameConfig {

    // MARK: - World / Layout

    /// Logical world width, matching the legacy 750-wide scene.
    static let worldWidth: Double = 750

    /// World size for a screen, keeping the 750-unit width and the screen's aspect ratio.
    static func worldSize(forScreen screen: CGSize) -> CGSize {
        guard screen.width > 0 else { return CGSize(width: worldWidth, height: 1334) }
        return CGSize(width: worldWidth, height: worldWidth * screen.height / screen.width)
    }

    // MARK: - Player

    static let playerSize          = CGSize(width: 64, height: 125)
    static let monsterTruckSize    = CGSize(width: 300, height: 301)
    /// Maximum lateral speed in world units per second at full input.
    static let playerMaxSpeed: Double = 900
    /// Player centre sits this far above the bottom edge (legacy: 1.5 × car height).
    static let playerBottomOffset: Double = 187.5
    /// Pixels the player re-enters from the opposite edge while wrapping.
    static let wrapInset: Double = 20

    // MARK: - Controls

    /// Steering input per g of sideways tilt. Legacy moved `accel.x × 37.5` units per
    /// frame (2,250 units/s per g); 2.5 × `playerMaxSpeed` reproduces that speed,
    /// reaching full speed at about 24° of tilt.
    static let tiltSensitivity: Double = 2.5
    /// Seconds between accelerometer samples (legacy 0.2 s felt laggy; 60 Hz instead).
    static let tiltUpdateInterval: Double = 1.0 / 60
    /// A touch that moves less than this many points is a tap (honk), not a drag.
    static let tapMaxTravel: Double = 10

    // MARK: - Lives

    static let beginningLifeCount: Int = 3
    static let maxLifeCount: Int       = 4

    // MARK: - Scoring

    /// Score points awarded per second of survival (legacy: +1 per frame at 60 fps).
    static let scoreRatePerSecond: Double = 60

    // MARK: - Speed ramp
    // Legacy `gameSpeed`: the seconds an obstacle takes to cross the screen.

    /// Starting travel duration (seconds to cross the full world height).
    static let startTravelDuration: Double = 2.0
    /// Fastest the game ever gets.
    static let minTravelDuration: Double   = 0.2
    /// How often (seconds) the travel duration steps down.
    static let speedRampInterval: Double   = 10.0
    /// How much the travel duration decreases each ramp step.
    static let speedRampStep: Double       = 0.1

    // MARK: - Spawn intervals (seconds between spawns)

    static let obstacleSpawnInterval: Double    = 1.75
    static let environmentSpawnInterval: Double = 1.0
    static let powerUpSpawnInterval: Double     = 5.0

    // MARK: - Spawn X ranges (fraction of world width, legacy GlobalConstants)

    /// Potholes and black ice spawn within ±this fraction of the width.
    static let centralSpawnFraction: Double = 0.25
    /// Phones spawn within ±this fraction of the width.
    static let phoneSpawnFraction: Double   = 0.4
    /// Plants spawn at ±this fraction of the width (road side).
    static let plantSpawnFraction: Double   = 0.4375
    /// Dogs and humans start at ±this fraction of the width.
    static let pedestrianSpawnFraction: Double = 0.375
    /// Moving cars drift between these fractions of the half-width.
    static let movingCarLanes: (near: Double, far: Double) = (0.2, 0.3375)
    /// Cone patterns' left edge range, as fractions of the width.
    static let conePatternRange: (low: Double, high: Double) = (-0.375, 0.25)

    // MARK: - Patterns

    static let coinTileSize = CGSize(width: 25, height: 50)
    static let coneTileSize = CGSize(width: 40, height: 40)
    /// Patterns taller than this many rows travel proportionally slower (legacy `minRows`).
    static let patternBaseRows: Int = 9
    /// Seconds (at start speed) the obstacle spawner pauses for a cone pattern.
    static let conePatternPause: Double = 25

    // MARK: - Horn

    /// Seconds the horn blast / missile takes to reach its target height.
    static let hornTravelDuration: Double = 1.0
    /// Horn hit box is this many times wider than its sprite.
    static let hornHitboxWidthMultiplier: Double = 5
    static let hornSize    = CGSize(width: 32, height: 32)
    static let missileSize = CGSize(width: 47, height: 121)

    // MARK: - Pedestrian reactions

    /// Seconds a scared or dying pedestrian takes for its reaction (legacy `runAway` duration).
    static let fleeDuration: Double = 2.0

    // MARK: - Powerup durations (seconds)

    static let wrapDuration: Double         = 15
    static let multiplierDuration: Double   = 30
    static let monsterTruckDuration: Double = 18
    static let boozeDuration: Double        = 15

    // MARK: - Recovery (post-collision invincibility, seconds)

    /// Legacy flash: 8 × (0.3 s fade out + 0.3 s fade in).
    static let recoveryDuration: Double = 4.8

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

    /// Number of lyric lines shown in order before wrapping back to the first.
    /// (Legacy wrapped at 57 and never showed its 58th line.)
    static var textMessageCount: Int { TextMessageLyrics.lines.count }

    // MARK: - Spawn tables

    /// Obstacle pool mirroring the legacy `possibleObstacles` array
    /// (its "coin" entries fell through to pothole, hence 7).
    static let obstacleWeights: [(ObstacleSpawn, Int)] = [
        (.single(.pothole),   7),
        (.single(.human),     4),
        (.single(.dog),       3),
        (.single(.movingCar), 3),
        (.single(.blackIce),  3),
        (.single(.policeCar), 2),
        (.single(.ambulance), 2),
        (.conePattern,        1),
    ]

    /// Environment pool (legacy: 9 in 10 plant, otherwise a coin pattern).
    static let environmentWeights: [(EnvSpawnType, Int)] = [
        (.plant,       9),
        (.coinPattern, 1),
    ]

    /// Power-up pool. Reproduces the odds the legacy `addPowerUp()` actually
    /// produced (it re-rolled the die in every `else if`), as an explicit table.
    static let powerUpWeights: [(PowerUpSpawn, Int)] = [
        (.powerUp(.oneUp),        14),
        (.powerUp(.monsterTruck), 13),
        (.powerUp(.wrap),         12),
        (.multiplier,             10),
        (.phone,                   9),
        (.powerUp(.booze),         8),
        (.nothing,                34),
    ]
}

/// One roll of the obstacle spawner.
enum ObstacleSpawn: Equatable {
    case single(ObstacleType)
    case conePattern
}

/// One roll of the environment spawner.
enum EnvSpawnType: Equatable {
    case plant
    case coinPattern
}

/// One roll of the power-up spawner.
enum PowerUpSpawn: Equatable {
    case powerUp(PowerUpType)
    /// x2 or x3, chosen 50/50.
    case multiplier
    /// The phone is a power-*down* obstacle.
    case phone
    case nothing
}
