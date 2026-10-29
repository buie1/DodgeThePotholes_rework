import Foundation
import CoreGraphics

/// Value-type snapshot of a single obstacle in the simulation.
struct ObstacleEntity: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var velocity: CGVector
    var type: ObstacleType
    /// Set to `true` when the obstacle has been destroyed/collected.
    /// The engine prunes `isRemoved` entities at the end of each tick.
    var isRemoved: Bool = false

    // MARK: - Geometry

    var boundingRect: CGRect {
        CGRect(
            x: position.x - size.width  / 2,
            y: position.y - size.height / 2,
            width:  size.width,
            height: size.height
        )
    }

    /// Returns `true` when the obstacle has scrolled fully below the world boundary.
    func isOffScreen(worldMinY: Double) -> Bool {
        position.y + size.height / 2 < worldMinY
    }
}
