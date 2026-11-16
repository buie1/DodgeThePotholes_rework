import Foundation

/// Counts from one run, shown on the game-over screen.
struct RunStats: Equatable {
    /// Coins picked up (not money: a multiplier makes each coin worth more).
    var coins = 0
    /// Obstacles the monster truck destroyed.
    var smashed = 0
    /// Dogs and people the horn scared off the road.
    var scared = 0
    /// Power-ups that took effect.
    var powerUps = 0
    /// Obstacles passed within a near-miss.
    var nearMisses = 0
    /// The highest combo multiplier reached.
    var bestMultiplier = 1
}
