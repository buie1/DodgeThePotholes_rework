import Foundation
import CoreGraphics

/// Value-type snapshot of a spawned power-up collectible.
struct PowerUpEntity: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var velocity: CGVector
    var type: PowerUpType
    var isCollected: Bool = false

    var boundingRect: CGRect {
        CGRect(
            x: position.x - size.width  / 2,
            y: position.y - size.height / 2,
            width:  size.width,
            height: size.height
        )
    }

    func isOffScreen(worldMinY: Double) -> Bool {
        position.y + size.height / 2 < worldMinY
    }
}

/// Value-type snapshot of a single coin collectible.
struct CoinEntity: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var velocity: CGVector
    var isCollected: Bool = false

    var boundingRect: CGRect {
        CGRect(
            x: position.x - size.width  / 2,
            y: position.y - size.height / 2,
            width:  size.width,
            height: size.height
        )
    }

    func isOffScreen(worldMinY: Double) -> Bool {
        position.y + size.height / 2 < worldMinY
    }
}

/// A horn blast (or, in monster-truck mode, a missile) fired up the road by a tap.
struct HornEntity: Identifiable {
    let id: UUID
    var position: CGPoint
    /// Sprite size at launch; the renderer widens the horn blast as it travels.
    let size: CGSize
    var velocity: CGVector
    let isMissile: Bool
    /// Seconds since launch.
    var age: Double = 0
    var isRemoved: Bool = false

    /// Legacy physics body: several times wider than the sprite.
    var collisionRect: CGRect {
        let width = size.width * GameConfig.hornHitboxWidthMultiplier
        return CGRect(x: position.x - width / 2, y: position.y - size.height / 2,
                      width: width, height: size.height)
    }

    /// 0 at launch → 1 on arrival. Drives the renderer's widening effect.
    var progress: Double { min(1, age / GameConfig.hornTravelDuration) }
}
