import SpriteKit

/// A sprite for an obstacle, remembering which phase its animation shows.
final class ObstacleNode: SKSpriteNode {
    var phase: ObstaclePhase = .moving
}

/// Builds and animates sprites for engine entities using the legacy art and timings.
///
/// Rendering only: nothing here decides gameplay. Textures are cached per name.
@MainActor
final class EntityNodeFactory {

    private enum ActionKey {
        static let animation = "animation"
    }

    private var cache: [String: SKTexture] = [:]

    // MARK: - Obstacles

    func makeObstacleNode(for obstacle: ObstacleEntity) -> ObstacleNode {
        let node = ObstacleNode(texture: baseTexture(for: obstacle), size: obstacle.size)
        node.zPosition = 1
        node.xScale = obstacle.facing
        node.yScale = obstacle.isOncoming ? -1 : 1
        if let (frames, timePerFrame) = movingAnimation(for: obstacle) {
            node.run(.repeatForever(.animate(with: frames, timePerFrame: timePerFrame)),
                     withKey: ActionKey.animation)
        }
        return node
    }

    /// Switches the sprite's animation when a dog or person starts fleeing or dying.
    func applyPhase(of obstacle: ObstacleEntity, to node: ObstacleNode) {
        guard node.phase != obstacle.phase else { return }
        node.phase = obstacle.phase
        node.xScale = obstacle.facing
        node.removeAction(forKey: ActionKey.animation)

        switch (obstacle.type, obstacle.phase, obstacle.variant) {
        case (.dog, .dying, _):
            node.texture = texture(SpriteCatalog.Image.dogDead.rawValue)
        case (.dog, .fleeing, _):
            node.run(.repeatForever(.animate(with: frames(.dogRun), timePerFrame: 0.1)),
                     withKey: ActionKey.animation)
        case (.human, .dying, _):
            // Legacy used the old man's death frames for every pedestrian.
            node.run(.animate(with: frames(.oldManDead), timePerFrame: 0.1), withKey: ActionKey.animation)
        case (.human, .fleeing, .pedestrian(let kind)):
            let jump: SpriteCatalog.Animation = kind == .oldMan ? .oldManJump : .buffGuyJump
            node.run(.animate(with: frames(jump), timePerFrame: 0.05), withKey: ActionKey.animation)
        default:
            break
        }
    }

    private func baseTexture(for obstacle: ObstacleEntity) -> SKTexture {
        switch (obstacle.type, obstacle.variant) {
        case (.pothole, .pothole(let number)): return texture("pothole\(number)")
        case (.pothole, _):                     return texture(SpriteCatalog.Image.pothole1.rawValue)
        case (.blackIce, _):                    return texture(SpriteCatalog.Image.ice.rawValue)
        case (.cone, _):                        return texture(SpriteCatalog.Image.cone.rawValue)
        case (.barricade, _):                   return texture(SpriteCatalog.Image.barricade.rawValue)
        case (.textMessage, _):                 return texture(SpriteCatalog.Image.phone.rawValue)
        case (.plant, .plant(let kind)):        return texture(kind.rawValue)
        case (.plant, _):                       return texture(SpriteCatalog.Image.tree1.rawValue)
        case (.movingCar, .vehicle(let model, _)): return texture(model.rawValue)
        case (.dog, _):                         return texture(SpriteCatalog.Image.dogDefault.rawValue)
        default:
            return movingAnimation(for: obstacle)?.frames.first
                ?? texture(SpriteCatalog.Image.pothole1.rawValue)
        }
    }

    /// The looping animation an obstacle plays while on the road (legacy frame timings).
    private func movingAnimation(for obstacle: ObstacleEntity) -> (frames: [SKTexture], timePerFrame: TimeInterval)? {
        switch (obstacle.type, obstacle.variant) {
        case (.ambulance, _): return (frames(.ambulance), 0.3)
        case (.policeCar, _): return (frames(.police), 0.3)
        case (.dog, _):       return (frames(.dogRun), 0.2)
        case (.human, .pedestrian(let kind)):
            return (frames(kind == .oldMan ? .oldManWalk : .buffGuyWalk), 0.2)
        case (.movingCar, .vehicle(let model, let direction)):
            return (frames(vehicleAnimation(model, direction)), 0.4)
        default:
            return nil
        }
    }

    private func vehicleAnimation(_ model: VehicleModel, _ direction: DriftDirection) -> SpriteCatalog.Animation {
        switch (model, direction) {
        case (.taxi, .left):   return .taxiLeft
        case (.taxi, .right):  return .taxiRight
        case (.truck, .left):  return .truckLeft
        case (.truck, .right): return .truckRight
        case (.sedan, .left):  return .sedanLeft
        case (.sedan, .right): return .sedanRight
        }
    }

    // MARK: - Pickups

    func makePowerUpNode(for powerUp: PowerUpEntity) -> SKSpriteNode {
        let image: SpriteCatalog.Image
        switch powerUp.type {
        case .wrap:                  image = .powWrap
        case .multiplier(let value): image = value >= 3 ? .powX3 : .powX2
        case .monsterTruck:          image = .star
        case .booze:                 image = .beer
        case .oneUp:                 image = .oneup
        }
        return makeNode(image, size: powerUp.size)
    }

    func makeCoinNode(for coin: CoinEntity) -> SKSpriteNode {
        makeNode(.dollar, size: coin.size)
    }

    // MARK: - Horn

    func makeHornNode(for horn: HornEntity) -> SKSpriteNode {
        let node = makeNode(horn.isMissile ? .missle : .carHorn, size: horn.size)
        node.zPosition = 2
        return node
    }

    /// The horn blast widens to 15× as it travels (legacy `resize(toWidth:)`); missiles don't.
    func updateHornNode(_ node: SKSpriteNode, for horn: HornEntity) {
        guard !horn.isMissile else { return }
        node.size.width = horn.size.width * (1 + 14 * horn.progress)
    }

    // MARK: - Textures

    func texture(_ name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    func frames(_ animation: SpriteCatalog.Animation) -> [SKTexture] {
        animation.frameNames.map(texture)
    }

    private func makeNode(_ image: SpriteCatalog.Image, size: CGSize) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(image.rawValue), size: size)
        node.zPosition = 1
        return node
    }
}
