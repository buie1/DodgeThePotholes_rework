import Foundation
import CoreGraphics
import Observation

/// Pure-Swift game simulation engine.
///
/// **Responsibilities**
/// - Delta-time game loop (internal Task loop or external drive via `update(deltaTime:)`)
/// - Obstacle / environment / power-up spawning from weighted `SpawnTables`
/// - AABB collision detection, horn blasts, and power-up timers
/// - Player movement, screen clamping, and edge wrapping
/// - Speed ramp: obstacles cross the screen faster every 10 s
/// - Score accumulation, life management, and game-over signalling
///
/// **No coupling** to UIKit, SpriteKit, or SwiftUI. All coordinates are world
/// units with the origin at the centre and Y pointing up (see `GameConfig`).
/// The caller reads `@Observable` state for rendering, `frameEvents` for one-shot
/// effects, and receives gameplay callbacks via `GameEngineDelegate`.
@Observable
@MainActor
final class GameEngine {

    // MARK: - Public observable state

    private(set) var state: GameState = .idle
    private(set) var score: Int = 0
    private(set) var money: Int = 0
    private(set) var player: PlayerEntity
    private(set) var obstacles: [ObstacleEntity] = []
    private(set) var powerUpEntities: [PowerUpEntity] = []
    private(set) var coins: [CoinEntity] = []
    private(set) var horns: [HornEntity] = []
    /// Timed power-ups currently running, oldest first.
    private(set) var activePowerUps: [PowerUpState] = []
    /// Seconds a newly spawned obstacle takes to cross the screen (legacy `gameSpeed`).
    private(set) var travelDuration: Double
    /// One-shot visual effects emitted during the most recent `update`.
    private(set) var frameEvents: [GameEvent] = []

    /// Road scroll speed in world units per second.
    var roadSpeed: Double { worldSize.height / travelDuration }

    // MARK: - Configuration

    let worldSize: CGSize

    // MARK: - Delegate

    weak var delegate: (any GameEngineDelegate)?

    // MARK: - Private state

    @ObservationIgnored private let spawner: EntitySpawner
    @ObservationIgnored private let tuning: GameTuning
    @ObservationIgnored private let tables: SpawnTables
    @ObservationIgnored private let coinPatterns: [TilePattern]
    @ObservationIgnored private let conePatterns: [TilePattern]
    @ObservationIgnored private let drivesOwnLoop: Bool
    /// One random stream per spawner, so the roll sequence of each never depends on
    /// which spawner fires first in a frame (and so not on the device's frame rate).
    @ObservationIgnored private var obstacleRNG: AnyRandomGenerator
    @ObservationIgnored private var environmentRNG: AnyRandomGenerator
    @ObservationIgnored private var powerUpRNG: AnyRandomGenerator

    @ObservationIgnored private var obstacleSpawnAccumulator: Double = 0
    @ObservationIgnored private var envSpawnAccumulator: Double      = 0
    @ObservationIgnored private var powerUpSpawnAccumulator: Double  = 0
    @ObservationIgnored private var speedRampAccumulator: Double     = 0
    @ObservationIgnored private var scoreAccumulator: Double         = 0
    /// Seconds the obstacle spawner stays quiet after a cone pattern.
    @ObservationIgnored private var obstacleSpawnPause: Double       = 0
    /// Next rickroll lyric to show.
    @ObservationIgnored private var nextTextMessageIndex: Int        = 0

    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var lastUpdateDate: Date = .now

    /// Normalised horizontal input in [-1, 1]. Positive = right.
    @ObservationIgnored private var horizontalInput: Double = 0

    // MARK: - Init

    /// - Parameters:
    ///   - worldSize: World size in world units; see `GameConfig.worldSize(forScreen:)`.
    ///   - carSkin: The player's car.
    ///   - tuning: Balance values (lives, speed, spawn rates, durations).
    ///   - tables: Spawn pools to roll on; defaults to `tuning`'s pools.
    ///   - rng: Random source the spawner streams are seeded from; pass a seeded
    ///     generator for a reproducible road.
    ///   - drivesOwnLoop: `true` to tick on an internal ~60 fps task;
    ///     `false` when the caller calls `update(deltaTime:)` itself.
    init(
        worldSize: CGSize,
        carSkin: CarSkin = GameCatalog.bundled.defaultCar,
        tuning: GameTuning = .bundled,
        tables: SpawnTables? = nil,
        rng: some RandomNumberGenerator = SystemRandomNumberGenerator(),
        drivesOwnLoop: Bool = true
    ) {
        self.worldSize = worldSize
        self.spawner = EntitySpawner(world: worldSize)
        self.tuning = tuning
        self.tables = tables ?? tuning.weights
        self.travelDuration = tuning.speed.startTravelDuration
        self.coinPatterns = TilePattern.loadAll(TilePattern.Name.money)
        self.conePatterns = TilePattern.loadAll(TilePattern.Name.cone)
        var source = rng
        self.obstacleRNG    = AnyRandomGenerator(SplitMix64(seed: source.next()))
        self.environmentRNG = AnyRandomGenerator(SplitMix64(seed: source.next()))
        self.powerUpRNG     = AnyRandomGenerator(SplitMix64(seed: source.next()))
        self.drivesOwnLoop = drivesOwnLoop
        self.player = GameEngine.makePlayer(worldSize: worldSize, skin: carSkin, lives: tuning.lives.start)
    }

    // MARK: - Lifecycle

    /// Start or restart a session from the initial state.
    /// - Parameters:
    ///   - carSkin: The player's car.
    ///   - extraLives: Lives added to the tuning's starting lives (a bought extra life).
    ///   - hasTank: Whether monster-truck mode shows the tank upgrade.
    func start(carSkin: CarSkin = GameCatalog.bundled.defaultCar, extraLives: Int = 0, hasTank: Bool = false) {
        resetState(carSkin: carSkin)
        player.lives = min(tuning.lives.start + extraLives, tuning.lives.max)
        player.hasTank = hasTank
        state = .playing
        startLoop()
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        stopLoop()
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        startLoop()
    }

    /// Force-stop without triggering the game-over delegate (used for cleanup).
    func forceStop() {
        state = .gameOver
        stopLoop()
    }

    // MARK: - Input

    /// Provide normalised horizontal steering in the range [-1, 1].
    /// Positive values steer right; negative steer left.
    func setHorizontalInput(_ value: Double) {
        horizontalInput = max(-1, min(1, value))
    }

    /// Sound the horn: a blast that scares dogs and people off the road,
    /// or a missile while in monster-truck mode.
    func honk() {
        guard state == .playing else { return }
        let isMissile = player.isMonsterTruck
        horns.append(spawner.horn(from: player.position, isMissile: isMissile))
        delegate?.engine(self, requestsSound: isMissile ? .pewPew : .carHonk)
    }

    // MARK: - Simulation step

    /// Advance the simulation by `dt` seconds. Capped at 50 ms to prevent
    /// large jumps after backgrounding.
    func update(deltaTime dt: Double) {
        // Cleared even when idle so a renderer never replays last frame's effects.
        if !frameEvents.isEmpty { frameEvents.removeAll(keepingCapacity: true) }
        guard state == .playing else { return }
        let dt = min(dt, 0.05)

        updatePlayer(dt: dt)
        moveEntities(dt: dt)
        updateHorns(dt: dt)
        updateTimers(dt: dt)
        checkCollisions()
        guard state == .playing else { return }
        tickSpawners(dt: dt)
        tickSpeedRamp(dt: dt)
        tickScore(dt: dt)
        pruneOffScreen()
    }

    // MARK: - Internal Task loop (~60 fps)

    private func startLoop() {
        guard drivesOwnLoop else { return }
        loopTask?.cancel()
        lastUpdateDate = .now
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.state == .playing else { break }
                let now = Date.now
                let dt  = now.timeIntervalSince(self.lastUpdateDate)
                self.lastUpdateDate = now
                self.update(deltaTime: dt)
                try? await Task.sleep(for: .milliseconds(16))   // ~60 fps
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    // MARK: - Movement

    private func updatePlayer(dt: Double) {
        // Booze inverts steering.
        let input = player.isDrunk ? -horizontalInput : horizontalInput
        player.velocity.dx = input * GameConfig.playerMaxSpeed
        player.position.x += player.velocity.dx * dt

        let halfW = worldSize.width / 2
        if isActive(.wrap) {
            if player.position.x < -halfW { player.position.x = halfW - GameConfig.wrapInset }
            if player.position.x >  halfW { player.position.x = -halfW + GameConfig.wrapInset }
        } else {
            // Legacy clamp lets a quarter of the car hang off the edge.
            let bound = halfW - player.size.width / 4
            player.position.x = max(-bound, min(bound, player.position.x))
        }
    }

    private func moveEntities(dt: Double) {
        for i in obstacles.indices {
            obstacles[i].position.x += obstacles[i].velocity.dx * dt
            obstacles[i].position.y += obstacles[i].velocity.dy * dt
        }
        for i in powerUpEntities.indices {
            powerUpEntities[i].position.y += powerUpEntities[i].velocity.dy * dt
        }
        for i in coins.indices {
            coins[i].position.y += coins[i].velocity.dy * dt
        }
    }

    private func updateHorns(dt: Double) {
        for i in horns.indices where !horns[i].isRemoved {
            horns[i].age += dt
            horns[i].position.y += horns[i].velocity.dy * dt
            guard horns[i].age >= GameConfig.hornTravelDuration else { continue }
            horns[i].isRemoved = true
            if horns[i].isMissile {
                frameEvents.append(.explosion(at: horns[i].position))
                delegate?.engine(self, requestsSound: .explosion)
            }
        }
    }

    // MARK: - Timers

    private func updateTimers(dt: Double) {
        if player.isRecovering {
            player.recoveryRemaining = max(0, player.recoveryRemaining - dt)
            if !player.isRecovering {
                delegate?.engine(self, didChangePlayerState: player.state)
            }
        }

        var expired: [PowerUpType] = []
        for i in activePowerUps.indices {
            activePowerUps[i].remainingSeconds -= dt
            if activePowerUps[i].remainingSeconds <= 0 { expired.append(activePowerUps[i].type) }
        }
        guard !expired.isEmpty else { return }
        activePowerUps.removeAll { $0.remainingSeconds <= 0 }
        for type in expired {
            applyPowerUpExpiry(type)
            delegate?.engine(self, didDeactivatePowerUp: type)
        }
    }

    private func applyPowerUpExpiry(_ type: PowerUpType) {
        switch type {
        case .monsterTruck:
            player.isMonsterTruck = false
            player.size = GameConfig.playerSize
            delegate?.engine(self, didChangePlayerState: player.state)
        case .booze:
            player.isDrunk = false
            delegate?.engine(self, didChangePlayerState: player.state)
        default:
            break
        }
    }

    // MARK: - Collisions

    private func checkCollisions() {
        let playerRect = player.collisionRect

        for i in obstacles.indices where obstacles[i].isCollidable {
            guard obstacles[i].collisionRect.intersects(playerRect) else { continue }
            handlePlayerHitObstacle(at: i)
            guard state == .playing else { return }
        }

        for i in powerUpEntities.indices where !powerUpEntities[i].isCollected {
            guard powerUpEntities[i].boundingRect.intersects(playerRect) else { continue }
            collectPowerUp(at: i)
        }

        for i in coins.indices where !coins[i].isCollected {
            guard coins[i].boundingRect.intersects(playerRect) else { continue }
            collectCoin(at: i)
        }

        for h in horns.indices where !horns[h].isRemoved {
            let hornRect = horns[h].collisionRect
            guard let o = obstacles.indices.first(where: {
                obstacles[$0].isCollidable && obstacles[$0].type.isMoveable
                    && obstacles[$0].boundingRect.intersects(hornRect)
            }) else { continue }
            horns[h].isRemoved = true
            scareAway(at: o)
        }
    }

    private func handlePlayerHitObstacle(at index: Int) {
        if player.isMonsterTruck {
            obstacles[index].isRemoved = true
            frameEvents.append(.explosion(at: obstacles[index].position))
            delegate?.engine(self, requestsSound: .explosion)
            delegate?.engine(self, requestsHaptic: .collision)
            return
        }
        // Recovering cars pass through obstacles (legacy `Recover` physics category).
        guard !player.isRecovering else { return }

        switch obstacles[index].type {
        case .textMessage:
            // A distraction, not a crash: no life lost.
            obstacles[index].isRemoved = true
            delegate?.engine(self, didTriggerTextMessageAt: nextTextMessageIndex)
            nextTextMessageIndex = (nextTextMessageIndex + 1) % GameConfig.textMessageCount
            delegate?.engine(self, requestsSound: .textTone)
            return
        case .pothole, .blackIce:
            obstacles[index].isRemoved = true
            frameEvents.append(.spinOut)
            delegate?.engine(self, requestsSound: .carSkid)
        case .dog:
            obstacles[index].phase = .dying
            delegate?.engine(self, requestsSound: .dogWhimper)
        case .human:
            obstacles[index].phase = .dying
            delegate?.engine(self, requestsSound: .scream)
        case .movingCar, .policeCar, .ambulance, .plant:
            obstacles[index].isRemoved = true
            delegate?.engine(self, requestsSound: .crash)
        case .cone, .barricade:
            obstacles[index].isRemoved = true
        }
        delegate?.engine(self, requestsHaptic: .collision)
        loseLife()
    }

    /// A honked-at dog or person turns around and runs back off the road side it came from.
    private func scareAway(at index: Int) {
        let side = obstacles[index].facing
        let size = obstacles[index].size
        let position = obstacles[index].position
        let targetX = side * (worldSize.width / 2 + size.width)
        let targetY = -worldSize.height / 2 - size.height
        obstacles[index].phase = .fleeing
        obstacles[index].facing = -side
        obstacles[index].velocity = CGVector(
            dx: (targetX - position.x) / (GameConfig.fleeDuration * 0.25),
            dy: (targetY - position.y) / (GameConfig.fleeDuration / 2)
        )
        if obstacles[index].type == .human {
            delegate?.engine(self, requestsSound: .ohMyGod)
        }
    }

    // MARK: - Pickups

    private func collectPowerUp(at index: Int) {
        let type = powerUpEntities[index].type
        switch type {
        case .oneUp:
            powerUpEntities[index].isCollected = true
            guard player.lives < tuning.lives.max else { return }
            player.lives += 1
            delegate?.engine(self, didUpdateLives: player.lives)
            delegate?.engine(self, requestsHaptic: .lifeGained)
            return

        case .wrap, .multiplier:
            // Already running: the pickup rolls past untouched (legacy).
            guard !isActive(type) else { return }
            activate(type, duration: type == .wrap ? tuning.durations.wrap : tuning.durations.multiplier)

        case .monsterTruck:
            guard !player.isMonsterTruck else { return }
            player.recoveryRemaining = 0
            player.isMonsterTruck = true
            player.size = GameConfig.monsterTruckSize
            activate(type, duration: tuning.durations.monsterTruck)
            delegate?.engine(self, didChangePlayerState: player.state)

        case .booze:
            // Only a car in normal driving picks up booze (legacy contact rules).
            guard player.state == .normal else { return }
            player.isDrunk = true
            activate(type, duration: tuning.durations.booze)
            delegate?.engine(self, didChangePlayerState: player.state)
            delegate?.engine(self, didRaiseAlert: .dontDrinkAndDrive)
        }
        powerUpEntities[index].isCollected = true
        delegate?.engine(self, requestsHaptic: .powerUpActivated)
    }

    private func activate(_ type: PowerUpType, duration: Double) {
        let state = PowerUpState(type: type, remainingSeconds: duration, totalSeconds: duration)
        activePowerUps.append(state)
        delegate?.engine(self, didActivatePowerUp: state)
    }

    private func isActive(_ type: PowerUpType) -> Bool {
        activePowerUps.contains { $0.type.isSameKind(as: type) }
    }

    private func collectCoin(at index: Int) {
        coins[index].isCollected = true
        let multiplier = activePowerUps.lazy.compactMap { state -> Int? in
            if case .multiplier(let value) = state.type { return value }
            return nil
        }.first ?? 1
        money += multiplier
        delegate?.engine(self, didUpdateMoney: money)
        delegate?.engine(self, requestsSound: .money)
        delegate?.engine(self, requestsHaptic: .coinPickup)
    }

    // MARK: - Life management

    private func loseLife() {
        player.lives = max(0, player.lives - 1)
        delegate?.engine(self, didUpdateLives: player.lives)

        if player.lives <= 0 {
            state = .gameOver
            stopLoop()
            delegate?.engineDidEnd(self, finalScore: score, moneyEarned: money)
            return
        }

        // Brief invincibility while the car flashes.
        player.recoveryRemaining = tuning.durations.recovery
        delegate?.engine(self, didChangePlayerState: player.state)
    }

    // MARK: - Spawning

    private func tickSpawners(dt: Double) {
        if obstacleSpawnPause > 0 {
            obstacleSpawnPause -= dt
        } else {
            obstacleSpawnAccumulator += dt
            if obstacleSpawnAccumulator >= tuning.spawnIntervals.obstacle {
                obstacleSpawnAccumulator -= tuning.spawnIntervals.obstacle
                spawnObstacle()
            }
        }

        envSpawnAccumulator += dt
        if envSpawnAccumulator >= tuning.spawnIntervals.environment {
            envSpawnAccumulator -= tuning.spawnIntervals.environment
            spawnEnvironment()
        }

        powerUpSpawnAccumulator += dt
        if powerUpSpawnAccumulator >= tuning.spawnIntervals.powerUp {
            powerUpSpawnAccumulator -= tuning.spawnIntervals.powerUp
            spawnPowerUp()
        }
    }

    private func spawnObstacle() {
        switch weightedRandom(tables.obstacles, using: &obstacleRNG) {
        case .single(let type)?:
            obstacles.append(spawner.obstacle(type, travel: travelDuration, rng: &obstacleRNG))
        case .conePattern?:
            guard let pattern = conePatterns.randomElement(using: &obstacleRNG) else { return }
            obstacles += spawner.conePattern(pattern, travel: travelDuration, rng: &obstacleRNG)
            // Hold other obstacles back until the traffic zone has passed.
            obstacleSpawnPause = tuning.spawnIntervals.conePatternPause * travelDuration / tuning.speed.startTravelDuration
            obstacleSpawnAccumulator = 0
            delegate?.engine(self, didRaiseAlert: .trafficZone)
        case nil:
            break
        }
    }

    private func spawnEnvironment() {
        switch weightedRandom(tables.environment, using: &environmentRNG) {
        case .plant?:
            obstacles.append(spawner.plant(travel: travelDuration, rng: &environmentRNG))
        case .coinPattern?:
            guard let pattern = coinPatterns.randomElement(using: &environmentRNG) else { return }
            coins += spawner.coinPattern(pattern, travel: travelDuration, rng: &environmentRNG)
        case nil:
            break
        }
    }

    private func spawnPowerUp() {
        let type: PowerUpType
        switch weightedRandom(tables.powerUps, using: &powerUpRNG) {
        case .powerUp(let chosen)?:
            type = chosen
        case .multiplier?:
            type = .multiplier(Bool.random(using: &powerUpRNG) ? 2 : 3)
        case .phone?:
            obstacles.append(spawner.obstacle(.textMessage, travel: travelDuration, rng: &powerUpRNG))
            return
        case .nothing?, nil:
            return
        }
        powerUpEntities.append(spawner.powerUp(type, travel: travelDuration, rng: &powerUpRNG))
    }

    private func weightedRandom<T>(_ pool: [(T, Int)], using rng: inout AnyRandomGenerator) -> T? {
        let total = pool.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0 ..< total, using: &rng)
        for (item, weight) in pool {
            roll -= weight
            if roll < 0 { return item }
        }
        return pool.last?.0
    }

    // MARK: - Speed & score

    private func tickSpeedRamp(dt: Double) {
        speedRampAccumulator += dt
        guard speedRampAccumulator >= tuning.speed.rampInterval else { return }
        speedRampAccumulator -= tuning.speed.rampInterval
        travelDuration = max(travelDuration - tuning.speed.rampStep, tuning.speed.minTravelDuration)
    }

    private func tickScore(dt: Double) {
        scoreAccumulator += tuning.pointsPerSecond * dt
        let earned = Int(scoreAccumulator)
        guard earned > 0 else { return }
        scoreAccumulator -= Double(earned)
        score += earned
        delegate?.engine(self, didUpdateScore: score)
    }

    // MARK: - Off-screen pruning

    private func pruneOffScreen() {
        let minY = -worldSize.height / 2
        obstacles.removeAll       { $0.isRemoved || $0.isOffScreen(world: worldSize) }
        powerUpEntities.removeAll { $0.isCollected || $0.isOffScreen(worldMinY: minY) }
        coins.removeAll           { $0.isCollected || $0.isOffScreen(worldMinY: minY) }
        horns.removeAll           { $0.isRemoved }
    }

    // MARK: - State reset

    private func resetState(carSkin: CarSkin) {
        score    = 0
        money    = 0
        obstacles.removeAll()
        powerUpEntities.removeAll()
        coins.removeAll()
        horns.removeAll()
        activePowerUps.removeAll()
        frameEvents.removeAll()
        travelDuration              = tuning.speed.startTravelDuration
        obstacleSpawnAccumulator    = 0
        envSpawnAccumulator         = 0
        powerUpSpawnAccumulator     = 0
        speedRampAccumulator        = 0
        scoreAccumulator            = 0
        obstacleSpawnPause          = 0
        nextTextMessageIndex        = 0
        horizontalInput             = 0
        player = GameEngine.makePlayer(worldSize: worldSize, skin: carSkin, lives: tuning.lives.start)
    }

    private static func makePlayer(worldSize: CGSize, skin: CarSkin, lives: Int) -> PlayerEntity {
        PlayerEntity(
            position: CGPoint(x: 0, y: -worldSize.height / 2 + GameConfig.playerBottomOffset),
            velocity: .zero,
            size:     GameConfig.playerSize,
            carSkin:  skin,
            lives:    lives
        )
    }
}

// MARK: - Test hooks

#if DEBUG
extension GameEngine {
    /// Places an obstacle directly into the world. Tests only.
    func insert(_ obstacle: ObstacleEntity) { obstacles.append(obstacle) }

    /// Places a power-up pickup directly into the world. Tests only.
    func insert(_ powerUp: PowerUpEntity) { powerUpEntities.append(powerUp) }

    /// Places a coin directly into the world. Tests only.
    func insert(_ coin: CoinEntity) { coins.append(coin) }
}
#endif
