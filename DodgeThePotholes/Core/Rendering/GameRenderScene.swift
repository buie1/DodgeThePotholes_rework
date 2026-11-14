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

    #if DEBUG
    /// Draws every entity's hit box in a debug build.
    var showsHitboxes = false
    /// Smoothed frames per second, for the DEV overlay.
    private(set) var debugFPS: Double = 0
    private var hitboxLayer: SKNode?
    #endif

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
        #if DEBUG
        if dt > 0 { debugFPS = debugFPS == 0 ? 1 / dt : debugFPS * 0.9 + 0.1 / dt }
        drawHitboxes()
        #endif
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

// MARK: - Dev mode

#if DEBUG
extension GameRenderScene {
    /// Redraws the current engine state, for changes made while the scene is paused.
    func debugRedraw() {
        syncEntities()
        drawHitboxes()
    }

    /// Outlines the rectangles the engine collides: player blue, obstacles red,
    /// power-ups yellow, coins green, horns purple.
    private func drawHitboxes() {
        guard showsHitboxes else {
            hitboxLayer?.removeFromParent()
            hitboxLayer = nil
            return
        }
        let layer = hitboxLayer ?? makeHitboxLayer()
        // Same order as the colours in `makeHitboxLayer`.
        let boxes: [[CGRect]] = [
            [engine.player.collisionRect],
            engine.obstacles.filter(\.isCollidable).map(\.collisionRect),
            engine.powerUpEntities.filter { !$0.isCollected }.map(\.boundingRect),
            engine.coins.filter { !$0.isCollected }.map(\.boundingRect),
            engine.horns.filter { !$0.isRemoved }.map(\.collisionRect),
        ]
        for (node, rects) in zip(layer.children.compactMap { $0 as? SKShapeNode }, boxes) {
            let path = CGMutablePath()
            path.addRects(rects)
            node.path = path
        }
    }

    private func makeHitboxLayer() -> SKNode {
        let layer = SKNode()
        layer.zPosition = 10
        for color in [SKColor.systemBlue, .systemRed, .systemYellow, .systemGreen, .systemPurple] {
            let node = SKShapeNode()
            node.strokeColor = color
            node.lineWidth = 5
            node.fillColor = .clear
            layer.addChild(node)
        }
        addChild(layer)
        hitboxLayer = layer
        return layer
    }
}
#endif
