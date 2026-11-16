import SpriteKit

/// One-shot effect nodes: shock rings and pixel-spark bursts. Each removes itself
/// when done, so callers just add it to the scene. Presentation only.
@MainActor
enum EffectNodes {

    /// A ring that bursts out from `point` and fades.
    static func ring(at point: CGPoint, color: SKColor, radius: CGFloat = 30,
                     growth: CGFloat = 3.5, duration: TimeInterval = 0.3) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = point
        ring.strokeColor = color
        ring.lineWidth = 8
        ring.fillColor = .clear
        ring.zPosition = 4
        ring.run(.sequence([
            .group([.scale(to: growth, duration: duration), .fadeOut(withDuration: duration)]),
            .removeFromParent(),
        ]))
        return ring
    }

    /// Square "pixel" sparks flying out from `point` in a rough circle, shrinking and fading.
    static func sparks(at point: CGPoint, color: SKColor, count: Int, size: CGFloat,
                       distance: CGFloat, duration: TimeInterval) -> SKNode {
        let burst = SKNode()
        burst.position = point
        burst.zPosition = 4
        for i in 0..<count {
            let angle = (Double(i) + .random(in: -0.3...0.3)) / Double(count) * 2 * .pi
            let reach = distance * .random(in: 0.7...1.0)
            let spark = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
            spark.run(.group([
                .moveBy(x: cos(angle) * reach, y: sin(angle) * reach, duration: duration),
                .fadeOut(withDuration: duration),
                .scale(to: 0.3, duration: duration),
            ]))
            burst.addChild(spark)
        }
        burst.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
        return burst
    }
}

extension EffectNodes {
    /// Pixel-font text that rises from just above `point` and fades, e.g. "+150 NEAR MISS".
    /// Starts about a car-length up so it never covers the car, and stays inside the
    /// world's width so it never runs off screen.
    static func floatingText(_ text: String, at point: CGPoint, color: SKColor, worldWidth: CGFloat) -> SKNode {
        let label = SKLabelNode(fontNamed: "PressStart2P")
        label.text = text
        label.fontSize = 26
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        let halfRoom = worldWidth / 2 - label.frame.width / 2 - 12
        label.position = CGPoint(x: min(max(point.x, -halfRoom), halfRoom), y: point.y + 130)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 140, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
        return label
    }
}

extension BonusKind {
    /// The floating text's label and colour for this bonus.
    var effect: (label: String, color: SKColor) {
        switch self {
        case .nearMiss: return ("NEAR MISS", .yellow)
        case .smash:    return ("SMASH", .orange)
        case .zone:     return ("ZONE CLEAR", .green)
        }
    }
}

extension PowerUpType {
    /// The colour of this power-up's pickup burst.
    var effectColor: SKColor {
        switch self {
        case .wrap:         return .cyan
        case .multiplier:   return .yellow
        case .monsterTruck: return .orange
        case .booze:        return .purple
        case .oneUp:        return .systemPink
        }
    }
}
