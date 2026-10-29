import Foundation
import CoreGraphics

/// Type-erased random source so the engine can run on a seeded generator in tests.
struct AnyRandomGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: some RandomNumberGenerator) {
        self.base = base
    }

    mutating func next() -> UInt64 {
        base.next()
    }
}

/// Builds new entities with the legacy spawn positions, sizes, art and paths.
///
/// Pure value type: every method returns entities and never touches engine state.
/// Each entity's velocity is fixed at spawn from the current travel duration,
/// as the legacy `SKAction.move(…, duration: gameSpeed)` calls were.
struct EntitySpawner {
    let world: CGSize

    private var halfW: Double { world.width / 2 }
    private var halfH: Double { world.height / 2 }

    // MARK: - Obstacles

    /// A single obstacle of `type`. Cones and barricades normally come from `conePattern`.
    func obstacle(_ type: ObstacleType, travel: Double, rng: inout AnyRandomGenerator) -> ObstacleEntity {
        let size = type.size
        switch type {
        case .pothole, .blackIce:
            let r = world.width * GameConfig.centralSpawnFraction - size.width / 2
            var entity = falling(type, x: random(-r, r, &rng), travel: travel)
            if type == .pothole { entity.variant = .pothole(Int.random(in: 1...2, using: &rng)) }
            return entity

        case .textMessage:
            let r = world.width * GameConfig.phoneSpawnFraction - size.width / 2
            return falling(type, x: random(-r, r, &rng), travel: travel)

        case .policeCar:
            // Left (oncoming) lane only.
            let x = random(-world.width / 4 + size.width / 2, -size.width / 2, &rng)
            var entity = falling(type, x: x, travel: travel)
            entity.isOncoming = true
            return entity

        case .ambulance:
            let r = world.width / 4 - size.width / 2
            let x = random(-r, r, &rng)
            var entity = falling(type, x: x, travel: travel)
            entity.isOncoming = x < 0
            return entity

        case .movingCar:
            return movingCar(travel: travel, rng: &rng)

        case .dog, .human:
            return pedestrian(type, travel: travel, rng: &rng)

        case .plant:
            return plant(travel: travel, rng: &rng)

        case .cone, .barricade:
            return falling(type, x: 0, travel: travel)
        }
    }

    /// A tree or bush on either road side.
    func plant(travel: Double, rng: inout AnyRandomGenerator) -> ObstacleEntity {
        let side: Double = Bool.random(using: &rng) ? 1 : -1
        var entity = falling(.plant, x: side * world.width * GameConfig.plantSpawnFraction, travel: travel)
        entity.variant = .plant(PlantKind.allCases.randomElement(using: &rng)!)
        return entity
    }

    /// A taxi, truck or sedan drifting diagonally between the right-hand lanes.
    private func movingCar(travel: Double, rng: inout AnyRandomGenerator) -> ObstacleEntity {
        let size = ObstacleType.movingCar.size
        let model = VehicleModel.allCases.randomElement(using: &rng)!
        let direction = DriftDirection.allCases.randomElement(using: &rng)!
        let lanes = GameConfig.movingCarLanes
        let (startX, endX) = direction == .left
            ? (lanes.far * halfW, lanes.near * halfW)
            : (lanes.near * halfW, lanes.far * halfW)
        let startY = halfH + size.height / 2
        let endY = -(halfH + size.height / 2)
        return ObstacleEntity(
            id: UUID(),
            position: CGPoint(x: startX, y: startY),
            size: size,
            velocity: CGVector(dx: (endX - startX) / travel, dy: (endY - startY) / travel),
            type: .movingCar,
            variant: .vehicle(model, direction)
        )
    }

    /// A dog or person stepping out from one road side and crossing diagonally.
    private func pedestrian(_ type: ObstacleType, travel: Double, rng: inout AnyRandomGenerator) -> ObstacleEntity {
        let size = type.size
        let side: Double = Bool.random(using: &rng) ? 1 : -1
        let start = CGPoint(x: side * (world.width * GameConfig.pedestrianSpawnFraction + size.width / 2),
                            y: halfH + size.height / 2)
        let targetX = side * world.width / Double(Int.random(in: 1...10, using: &rng))
        let targetY = -world.height
        var entity = ObstacleEntity(
            id: UUID(),
            position: start,
            size: size,
            velocity: CGVector(dx: (targetX - start.x) / travel, dy: (targetY - start.y) / travel),
            type: type,
            facing: side
        )
        if type == .human {
            entity.variant = .pedestrian(PedestrianKind.allCases.randomElement(using: &rng)!)
        }
        return entity
    }

    // MARK: - Patterns

    /// Coins laid out by a money pattern, moving down the road as one rigid block.
    func coinPattern(_ pattern: TilePattern, travel: Double, rng: inout AnyRandomGenerator) -> [CoinEntity] {
        let tile = GameConfig.coinTileSize
        let block = CGSize(width: tile.width * Double(pattern.numCols), height: tile.height * Double(pattern.numRows))
        let left = random(-halfW, halfW - block.width, &rng)
        let velocity = patternVelocity(pattern, block: block, travel: travel)
        let grid = pattern.grid
        var coins: [CoinEntity] = []
        for row in 0..<pattern.numRows {
            for col in 0..<pattern.numCols where grid[col, row] == 1 {
                coins.append(CoinEntity(
                    id: UUID(),
                    position: tilePosition(col: col, row: row, left: left, tile: tile, block: block),
                    size: CGSize(width: tile.width / 2, height: tile.height / 2),
                    velocity: velocity
                ))
            }
        }
        return coins
    }

    /// Cones (value 1) and barricades (value 2, first and last rows only) from a cone pattern.
    func conePattern(_ pattern: TilePattern, travel: Double, rng: inout AnyRandomGenerator) -> [ObstacleEntity] {
        let tile = GameConfig.coneTileSize
        let block = CGSize(width: tile.width * Double(pattern.numCols), height: tile.height * Double(pattern.numRows))
        let range = GameConfig.conePatternRange
        var low = max(world.width * range.low, -halfW)
        var high = min(world.width * range.high - block.width, halfW - block.width)
        if low > high { (low, high) = (-halfW, halfW - block.width) }
        let left = random(low, high, &rng)
        let velocity = patternVelocity(pattern, block: block, travel: travel)
        let grid = pattern.grid
        var obstacles: [ObstacleEntity] = []
        for row in 0..<pattern.numRows {
            let isEdgeRow = row == 0 || row == pattern.numRows - 1
            for col in 0..<pattern.numCols {
                let type: ObstacleType
                switch grid[col, row] {
                case 1: type = .cone
                case 2 where isEdgeRow: type = .barricade
                default: continue
                }
                obstacles.append(ObstacleEntity(
                    id: UUID(),
                    position: tilePosition(col: col, row: row, left: left, tile: tile, block: block),
                    size: type.size,
                    velocity: velocity,
                    type: type
                ))
            }
        }
        return obstacles
    }

    // MARK: - Power-ups

    func powerUp(_ type: PowerUpType, travel: Double, rng: inout AnyRandomGenerator) -> PowerUpEntity {
        let size = type.spawnSize
        let r = halfW - size.width / 2
        let startY = halfH + size.height / 2
        let endY = -halfH - size.height
        return PowerUpEntity(
            id: UUID(),
            position: CGPoint(x: random(-r, r, &rng), y: startY),
            size: size,
            velocity: CGVector(dx: 0, dy: (endY - startY) / travel),
            type: type
        )
    }

    // MARK: - Horn

    /// A horn blast or missile launched from the player toward a quarter of the way up the screen.
    func horn(from origin: CGPoint, isMissile: Bool) -> HornEntity {
        let size = isMissile ? GameConfig.missileSize : GameConfig.hornSize
        let start = CGPoint(x: origin.x, y: origin.y + 5)
        let targetY = halfH / 2 + size.height
        return HornEntity(
            id: UUID(),
            position: start,
            size: size,
            velocity: CGVector(dx: 0, dy: (targetY - start.y) / GameConfig.hornTravelDuration),
            isMissile: isMissile
        )
    }

    // MARK: - Helpers

    /// Straight drop from just above the top edge to one sprite-height below the bottom.
    private func falling(_ type: ObstacleType, x: Double, travel: Double) -> ObstacleEntity {
        let size = type.size
        let startY = halfH + size.height / 2
        let endY = -halfH - size.height
        return ObstacleEntity(
            id: UUID(),
            position: CGPoint(x: x, y: startY),
            size: size,
            velocity: CGVector(dx: 0, dy: (endY - startY) / travel),
            type: type
        )
    }

    /// Patterns taller than the base row count travel proportionally slower (legacy integer division).
    private func patternVelocity(_ pattern: TilePattern, block: CGSize, travel: Double) -> CGVector {
        let slowdown = Double(max(1, pattern.numRows / GameConfig.patternBaseRows))
        return CGVector(dx: 0, dy: -(world.height + 2 * block.height) / (travel * slowdown))
    }

    /// Centre of a tile, with the block's bottom row starting just above the top edge.
    private func tilePosition(col: Int, row: Int, left: Double, tile: CGSize, block: CGSize) -> CGPoint {
        CGPoint(x: left + Double(col) * tile.width + tile.width / 2,
                y: halfH + block.height / 2 + Double(row) * tile.height + tile.height / 2)
    }

    /// Uniform value in `low...high`, or their midpoint if the range is empty.
    private func random(_ low: Double, _ high: Double, _ rng: inout AnyRandomGenerator) -> Double {
        guard low < high else { return (low + high) / 2 }
        return Double.random(in: low...high, using: &rng)
    }
}
