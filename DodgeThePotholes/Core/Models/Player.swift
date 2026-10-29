import Foundation
import CoreGraphics

/// Value-type snapshot of the player's simulation state.
/// Owned and mutated exclusively by `GameEngine`.
struct PlayerEntity {
    var position: CGPoint
    var velocity: CGVector
    var size: CGSize
    var state: PlayerState
    var carSkin: CarSkin
    var lives: Int

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

    /// Slightly inset rect used for physics contacts.
    /// Mirrors the legacy polygon body that covered only the front half.
    var collisionRect: CGRect {
        let insetX = size.width  * 0.12
        let insetYBottom = size.height * 0.30   // shorten rear of car
        return CGRect(
            x: position.x - size.width  / 2 + insetX,
            y: position.y - size.height / 2 + insetYBottom,
            width:  size.width  - insetX * 2,
            height: size.height - insetYBottom
        )
    }

    // MARK: - State helpers

    var isInvincible: Bool { state.isInvincible }
}
