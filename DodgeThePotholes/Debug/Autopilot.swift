#if DEBUG
import CoreGraphics

/// A simple bot driver for unattended dev runs and headless balance checks. Debug builds only.
///
/// Each step it scores a row of candidate x positions by how soon an oncoming obstacle
/// would reach each one, steers toward the safest (preferring small moves), and honks
/// at a dog or person ahead. It is deliberately simple: good enough to survive a while,
/// not to play perfectly.
struct Autopilot {

    /// How far ahead (seconds) the pilot reacts to obstacles.
    var lookahead: Double = 1.5
    /// Spacing (world units) between the candidate positions it considers.
    var candidateSpacing: Double = 25
    /// Extra clearance (world units) kept on each side of the car.
    var margin: Double = 20

    /// Steering in [-1, 1], and whether to honk this step.
    struct Decision: Equatable {
        var input: Double
        var honk: Bool
    }

    func decide(player: PlayerEntity, obstacles: [ObstacleEntity], worldWidth: Double) -> Decision {
        let halfW = worldWidth / 2
        let carHalfWidth = player.size.width / 2 + margin
        let front = player.position.y + player.size.height / 2

        // Each threat: when it reaches the car's front, and the x range it covers then.
        var threats: [(time: Double, minX: Double, maxX: Double, isMoveable: Bool)] = []
        for obstacle in obstacles where obstacle.isCollidable && obstacle.velocity.dy < 0 {
            let gap = obstacle.boundingRect.minY - front
            let time = max(0, gap / -obstacle.velocity.dy)
            guard time <= lookahead, obstacle.boundingRect.maxY > player.position.y - player.size.height / 2 else { continue }
            let x = obstacle.position.x + obstacle.velocity.dx * time
            threats.append((time, x - obstacle.size.width / 2, x + obstacle.size.width / 2, obstacle.type.isMoveable))
        }

        // Danger of driving at x: sooner collisions weigh more.
        func danger(at x: Double) -> Double {
            threats.reduce(0) { total, threat in
                let overlaps = x + carHalfWidth > threat.minX && x - carHalfWidth < threat.maxX
                return overlaps ? total + 1 / (threat.time + 0.1) : total
            }
        }

        // A grid centred on the road, plus staying put.
        let bound = halfW - player.size.width / 2
        let current = player.position.x
        let offsets = Array(stride(from: 0, through: bound, by: candidateSpacing))
        let candidates = offsets + offsets.dropFirst().map { -$0 } + [current]
        let target = candidates.min { a, b in
            // Danger first; then stay close to the current position, then near the centre.
            let costA = danger(at: a) * 1_000 + abs(a - current) + abs(a) * 0.1
            let costB = danger(at: b) * 1_000 + abs(b - current) + abs(b) * 0.1
            return costA < costB
        } ?? current

        var input = max(-1, min(1, (target - current) / 100))
        if player.isDrunk { input = -input }   // the engine inverts drunk steering

        let honk = threats.contains { threat in
            threat.isMoveable && current + carHalfWidth > threat.minX && current - carHalfWidth < threat.maxX
        }
        return Decision(input: input, honk: honk)
    }
}
#endif
