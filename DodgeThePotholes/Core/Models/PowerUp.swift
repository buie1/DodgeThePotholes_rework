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
