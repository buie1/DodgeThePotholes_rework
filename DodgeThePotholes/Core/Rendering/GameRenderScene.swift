import SpriteKit

/// An engine entity the scene places by its world position.
protocol PositionedEntity: Identifiable where ID == UUID {
    var position: CGPoint { get }
}

extension ObstacleEntity: PositionedEntity {}
extension PowerUpEntity: PositionedEntity {}
extension CoinEntity: PositionedEntity {}
extension HornEntity: PositionedEntity {}

/// Draws a `GameEngine` with SpriteKit and drives its clock.
///
/// The scene is sized in world units with its anchor at the centre, so engine
/// positions map 1:1 onto node positions. Each frame it advances the engine once,
/// then mirrors every entity onto a sprite keyed by the entity's id.
/// It never makes gameplay decisions.
@MainActor
final class GameRenderScene: SKScene {

    let engine: GameEngine

    private let factory = EntityNodeFactory()
    private let road: SKSpriteNode
    private let playerNode: PlayerNode

    private var obstacleNodes: [UUID: ObstacleNode] = [:]
    private var powerUpNodes: [UUID: SKSpriteNode] = [:]
    private var coinNodes: [UUID: SKSpriteNode] = [:]
    private var hornNodes: [UUID: SKSpriteNode] = [:]

    private var lastUpdateTime: TimeInterval?
    /// How far the road has scrolled within one screen height.
    private var roadOffset: Double = 0

    init(engine: GameEngine) {
        self.engine = engine
        // Legacy road: one `road_long` sprite four screens tall, scrolled and reset every screen.
        road = SKSpriteNode(texture: factory.texture(SpriteCatalog.Image.roadLong.rawValue),
                            size: CGSize(width: engine.worldSize.width, height: 4 * engine.worldSize.height))
        playerNode = PlayerNode(player: engine.player, factory: factory)
        super.init(size: engine.worldSize)

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFill
        backgroundColor = .black
        road.zPosition = -1
        addChild(road)
        addChild(playerNode)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        engine.update(deltaTime: dt)
        if engine.state == .playing { scrollRoad(dt: min(dt, 0.05)) }
        syncEntities()
        playEffects()
    }

    // MARK: - Road

    private func scrollRoad(dt: Double) {
        roadOffset = (roadOffset + engine.roadSpeed * dt).truncatingRemainder(dividingBy: size.height)
        road.position.y = -roadOffset
    }

    // MARK: - Entity sync

    private func syncEntities() {
        sync(engine.obstacles, into: &obstacleNodes, make: factory.makeObstacleNode) { obstacle, node in
            self.factory.applyPhase(of: obstacle, to: node)
        }
        sync(engine.powerUpEntities, into: &powerUpNodes, make: factory.makePowerUpNode)
        sync(engine.coins, into: &coinNodes, make: factory.makeCoinNode)
        sync(engine.horns, into: &hornNodes, make: factory.makeHornNode) { horn, node in
            self.factory.updateHornNode(node, for: horn)
        }
        playerNode.update(from: engine.player)
    }

    /// Creates sprites for new entities, moves existing ones, and removes sprites
    /// whose entity is gone.
    private func sync<Entity: PositionedEntity, Node: SKSpriteNode>(
        _ entities: [Entity],
        into nodes: inout [UUID: Node],
        make: (Entity) -> Node,
        update: (Entity, Node) -> Void = { _, _ in }
    ) {
        var live = Set<UUID>()
        for entity in entities {
            live.insert(entity.id)
            let node: Node
            if let existing = nodes[entity.id] {
                node = existing
            } else {
                node = make(entity)
                nodes[entity.id] = node
                addChild(node)
            }
            node.position = entity.position
            update(entity, node)
        }
        for (id, node) in nodes where !live.contains(id) {
            node.removeFromParent()
            nodes[id] = nil
        }
    }

    // MARK: - Effects

    private func playEffects() {
        for event in engine.frameEvents {
            switch event {
            case .spinOut:
                playerNode.spinOut()
            case .explosion(let point):
                addExplosion(at: point)
            }
        }
    }

    private func addExplosion(at point: CGPoint) {
        guard let explosion = SKEmitterNode(fileNamed: "Explosion") else { return }
        explosion.position = point
        explosion.zPosition = 3
        addChild(explosion)
        explosion.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))
    }
}
