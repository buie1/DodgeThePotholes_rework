import SpriteKit

/// Streaks rushing down the screen, more and brighter the faster the game goes.
/// Presentation only.
@MainActor
final class SpeedLines: SKNode {

    /// Below this intensity no streaks spawn, so the opening stretch looks calm.
    static let threshold: Double = 0.1
    /// Streaks per second at full intensity.
    static let maxRate: Double = 45

    private let worldSize: CGSize
    private var spawnCredit: Double = 0

    init(worldSize: CGSize) {
        self.worldSize = worldSize
        super.init()
        zPosition = 1.5   // above the road and obstacles, below the player
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Spawns and moves streaks. Call once per frame while playing.
    /// - Parameter intensity: 0 at the starting speed to 1 at top speed (`GameEngine.speedProgress`).
    func update(dt: Double, intensity: Double, roadSpeed: Double) {
        for case let streak as SKSpriteNode in children {
            streak.position.y -= roadSpeed * 1.6 * dt
            if streak.position.y < -worldSize.height / 2 - streak.size.height { streak.removeFromParent() }
        }
        guard intensity > Self.threshold else { return }
        spawnCredit += Self.maxRate * intensity * dt
        while spawnCredit >= 1 {
            spawnCredit -= 1
            addChild(makeStreak(intensity: intensity))
        }
    }

    private func makeStreak(intensity: Double) -> SKSpriteNode {
        let length = Double.random(in: 80...220) * (0.6 + 0.4 * intensity)
        let streak = SKSpriteNode(color: .white, size: CGSize(width: 3, height: length))
        streak.alpha = 0.1 + 0.3 * intensity
        streak.position = CGPoint(x: .random(in: -worldSize.width / 2...worldSize.width / 2),
                                  y: worldSize.height / 2 + length / 2)
        return streak
    }
}
