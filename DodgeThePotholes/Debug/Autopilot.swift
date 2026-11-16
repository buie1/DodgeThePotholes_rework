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
    /// When set, the pilot chases near-misses: among safe positions it prefers passing the
    /// next road obstacle about this many units clear, like a player building a combo.
    var nearMissTarget: Double?

    /// Drives close on purpose to chain near-misses: a stand-in for a skilled player.
    static let comboChaser = Autopilot(margin: 4, nearMissTarget: 14)

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
        var threats: [(time: Double, minX: Double, maxX: Double, isMoveable: Bool, nearMissable: Bool)] = []
        for obstacle in obstacles where obstacle.isCollidable && obstacle.velocity.dy < 0 {
            let gap = obstacle.boundingRect.minY - front
            let time = max(0, gap / -obstacle.velocity.dy)
            guard time <= lookahead, obstacle.boundingRect.maxY > player.position.y - player.size.height / 2 else { continue }
            let x = obstacle.position.x + obstacle.velocity.dx * time
            threats.append((time, x - obstacle.size.width / 2, x + obstacle.size.width / 2,
                            obstacle.type.isMoveable, obstacle.type.countsForNearMiss))
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
        // Chasing near-misses: how far `x` is from passing the soonest road obstacle at the target gap.
        let soonest = threats.filter(\.nearMissable).min { $0.time < $1.time }
        func nearMissCost(at x: Double) -> Double {
            guard let target = nearMissTarget, let soonest else { return 0 }
            let halfCar = player.size.width / 2
            let gap = max(soonest.minX - (x + halfCar), (x - halfCar) - soonest.maxX)
            return abs(gap - target) * 3
        }

        let target = candidates.min { a, b in
            // Danger first; then (when chasing) a near-miss pass; then stay close to the
            // current position, then near the centre.
            let costA = danger(at: a) * 1_000 + nearMissCost(at: a) + abs(a - current) + abs(a) * 0.1
            let costB = danger(at: b) * 1_000 + nearMissCost(at: b) + abs(b - current) + abs(b) * 0.1
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
