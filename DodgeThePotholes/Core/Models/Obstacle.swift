import Foundation
import CoreGraphics

/// Which art an obstacle uses, chosen at spawn time.
enum ObstacleVariant: Equatable {
    case none
    /// `pothole1` or `pothole2`.
    case pothole(Int)
    /// A moving car and the direction its turn-signal animation shows.
    case vehicle(VehicleModel, DriftDirection)
    case pedestrian(PedestrianKind)
    case plant(PlantKind)
}

enum VehicleModel: String, CaseIterable {
    case taxi, truck, sedan
}

enum DriftDirection: String, CaseIterable {
    case left, right
}

enum PedestrianKind: String, CaseIterable {
    case oldMan  = "old_man"
    case buffGuy = "buff_guy"
}

enum PlantKind: String, CaseIterable {
    case tree = "tree1"
    case bush = "bush1"
}

/// Lifecycle of an obstacle. Only `.moving` obstacles collide.
enum ObstaclePhase: Equatable {
    case moving
    /// Scared off by the horn; runs back off the side of the road.
    case fleeing
    /// Hit by the player; plays its death animation while drifting on.
    case dying
}

/// Value-type snapshot of a single obstacle in the simulation.
struct ObstacleEntity: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var velocity: CGVector
    var type: ObstacleType
    var variant: ObstacleVariant = .none
    var phase: ObstaclePhase = .moving
    /// Horizontal sprite scale sign: `1` faces right, `-1` is mirrored.
    var facing: Double = 1
    /// `true` for vehicles drawn upside down (driving toward the player).
    var isOncoming: Bool = false
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

    /// Hit box used for collisions. The phone's body is half its sprite width (legacy).
    var collisionRect: CGRect {
        guard type == .textMessage else { return boundingRect }
        return boundingRect.insetBy(dx: size.width / 4, dy: 0)
    }

    var isCollidable: Bool { phase == .moving && !isRemoved }

    /// Returns `true` once the obstacle has left the world: below the bottom edge,
    /// or (while fleeing) past either side.
    func isOffScreen(world: CGSize) -> Bool {
        if position.y + size.height / 2 < -world.height / 2 { return true }
        guard phase == .fleeing else { return false }
        return abs(position.x) - size.width / 2 > world.width / 2
    }
}
