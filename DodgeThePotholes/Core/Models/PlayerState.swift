import Foundation

/// Describes the player's current mode within a session.
enum PlayerState: Equatable {
    /// Normal driving — no active modifier.
    case normal
    /// Post-collision grace period; player flashes and is invincible.
    case recovering
    /// Monster-truck power-up active; player is invincible and destroys obstacles.
    case monsterTruck
    /// Booze power-up active; steering is inverted.
    case drunk

    /// `true` when the player cannot take damage.
    var isInvincible: Bool {
        self == .recovering || self == .monsterTruck
    }
}
