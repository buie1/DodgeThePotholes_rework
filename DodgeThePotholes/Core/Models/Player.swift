import Foundation
import CoreGraphics

/// Value-type snapshot of the player's simulation state.
/// Owned and mutated exclusively by `GameEngine`.
///
/// Monster-truck mode, drunk driving, and post-crash recovery are independent
/// (legacy allowed them to overlap); `state` reports the most visible one.
struct PlayerEntity {
    var position: CGPoint
    var velocity: CGVector
    var size: CGSize
    var carSkin: CarSkin
    var lives: Int
    var isMonsterTruck: Bool = false
    var isDrunk: Bool = false
    /// Seconds of post-collision invincibility left; `0` when not recovering.
    var recoveryRemaining: Double = 0

    // MARK: - Geometry

    /// Full sprite bounding rect centred on `position`.
    var boundingRect: CGRect {
        CGRect(
            x: position.x - size.width  / 2,
            y: position.y - size.height / 2,
            width:  size.width,
            height: size.height
        )
    }

    /// Hit box. The car's legacy polygon body covered only its front half;
    /// the monster truck used its whole frame.
    var collisionRect: CGRect {
        guard !isMonsterTruck else { return boundingRect }
        return CGRect(x: position.x - size.width / 2, y: position.y,
                      width: size.width, height: size.height / 2)
    }

    // MARK: - State helpers

    var isRecovering: Bool { recoveryRemaining > 0 }

    var state: PlayerState {
        if isMonsterTruck { return .monsterTruck }
        if isRecovering   { return .recovering }
        if isDrunk        { return .drunk }
        return .normal
    }

    var isInvincible: Bool { isMonsterTruck || isRecovering }
}
