import Foundation
import CoreGraphics
import Observation

// MARK: - CGVector convenience
extension CGVector {
    static let zero = CGVector(dx: 0, dy: 0)
}

/// Pure-Swift game simulation engine.
///
/// **Responsibilities**
/// - Delta-time game loop (internal Task loop or external drive via `update(deltaTime:)`)
/// - Obstacle / power-up / coin spawning with weighted random selection
/// - AABB bounding-box collision detection
/// - Player movement, screen clamping, and edge wrapping
/// - Speed ramp-up every 10 s
/// - Score accumulation, life management, and game-over signalling
///
/// **No coupling** to UIKit, SpriteKit, or SwiftUI.
/// The caller reads `@Observable` published state for rendering,
/// and receives event callbacks via `GameEngineDelegate`.
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
    private(set) var activePowerUp: PowerUpState? = nil
    private(set) var currentObstacleInterval: Double = GameConfig.startObstacleInterval

    // MARK: - Configuration

    let worldSize: CGSize

    // MARK: - Delegate

    weak var delegate: (any GameEngineDelegate)?

    // MARK: - Private timing state

    private var obstacleSpawnAccumulator: Double = 0
    private var envSpawnAccumulator: Double      = 0
    private var powerUpSpawnAccumulator: Double  = 0
    private var speedRampAccumulator: Double     = 0
    private var scoreAccumulator: Double         = 0

    // MARK: - Private loop state

    private var loopTask: Task<Void, Never>?
    private var lastUpdateDate: Date = .now

    // MARK: - Input (set by ViewModel from gesture/accelerometer)

    /// Normalised horizontal input in [-1, 1]. Positive = right.
    private var horizontalInput: Double = 0

    // MARK: - Init

    init(worldSize: CGSize, carSkin: CarSkin = .blue) {
        self.worldSize = worldSize
        self.player = GameEngine.makePlayer(worldSize: worldSize, skin: carSkin)
    }

    // MARK: - Lifecycle

    /// Start or restart a session from the initial state.
    func start(carSkin: CarSkin = .blue) {
        resetState(carSkin: carSkin)
        state = .playing
        lastUpdateDate = .now
        startLoop()
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        loopTask?.cancel()
        loopTask = nil
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        lastUpdateDate = .now
        startLoop()
    }

    /// Force-stop without triggering the game-over delegate (used for cleanup).
    func forceStop() {
        state = .gameOver
        loopTask?.cancel()
        loopTask = nil
    }

    // MARK: - Input

    /// Provide normalised horizontal steering in the range [-1, 1].
    /// Positive values steer right; negative steer left.
    /// Call this from `DragGesture.onChanged` or an accelerometer handler.
    func setHorizontalInput(_ value: Double) {
        horizontalInput = max(-1, min(1, value))
    }

    // MARK: - External drive
    // When integrated with SpriteKit, call this from `SKScene.update(_:)`.

    /// Advance the simulation by `dt` seconds. Capped at 50 ms to prevent
    /// large jumps after backgrounding.
    func update(deltaTime dt: Double) {
        guard state == .playing else { return }
        let clampedDt = min(dt, 0.05)

        updatePlayer(dt: clampedDt)
        updateObstacles(dt: clampedDt)
        updatePowerUpEntities(dt: clampedDt)
        updateCoins(dt: clampedDt)
        updateActivePowerUp(dt: clampedDt)
        checkCollisions()
        tickObstacleSpawn(dt: clampedDt)
        tickEnvironmentSpawn(dt: clampedDt)
        tickPowerUpSpawn(dt: clampedDt)
        tickSpeedRamp(dt: clampedDt)
        tickScore(dt: clampedDt)
        pruneOffScreen()
    }

    // MARK: - Internal Task loop (~60 fps)

    private func startLoop() {
        loopTask?.cancel()
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

    // MARK: - Player update

    private func updatePlayer(dt: Double) {
        // Invert steering while drunk
        let input: Double = player.state == .drunk ? -horizontalInput : horizontalInput
        player.velocity.dx = input * GameConfig.playerMaxSpeed
        player.position.x += player.velocity.dx * dt

        let halfW = worldSize.width / 2
        if case .wrap = activePowerUp?.type {
            // Edge wrapping
            let threshold = halfW + player.size.width / 2
            if player.position.x > threshold  { player.position.x = -threshold }
            if player.position.x < -threshold { player.position.x = threshold  }
        } else {
            // Clamp to lane boundaries
            let bound = halfW * GameConfig.laneHalfWidthFraction
            player.position.x = max(-bound, min(bound, player.position.x))
        }
    }

    // MARK: - World entity updates

    private func updateObstacles(dt: Double) {
        for i in obstacles.indices {
            obstacles[i].position.x += obstacles[i].velocity.dx * dt
            obstacles[i].position.y += obstacles[i].velocity.dy * dt
        }
    }

    private func updatePowerUpEntities(dt: Double) {
        for i in powerUpEntities.indices {
            powerUpEntities[i].position.y += powerUpEntities[i].velocity.dy * dt
        }
    }

    private func updateCoins(dt: Double) {
        for i in coins.indices {
            coins[i].position.y += coins[i].velocity.dy * dt
        }
    }

    private func updateActivePowerUp(dt: Double) {
        guard var active = activePowerUp else { return }
        active.remainingSeconds -= dt
        if active.remainingSeconds <= 0 {
            let expired = active.type
            activePowerUp = nil
            delegate?.engine(self, didDeactivatePowerUp: expired)
            applyPowerUpExpiry(expired)
        } else {
            activePowerUp = active
        }
    }

    private func applyPowerUpExpiry(_ type: PowerUpType) {
        switch type {
        case .monsterTruck:
            player.state = .normal
            player.size  = GameConfig.playerSize
            delegate?.engine(self, didChangePlayerState: .normal)
        case .booze:
            player.state = .normal
            delegate?.engine(self, didChangePlayerState: .normal)
        default:
            break
        }
    }

    // MARK: - AABB Collision detection

    private func checkCollisions() {
        let playerRect = player.collisionRect

        // Obstacle hits
        for i in obstacles.indices where !obstacles[i].isRemoved {
            guard obstacles[i].boundingRect.intersects(playerRect) else { continue }
            handlePlayerHitObstacle(at: i)
        }

        // Power-up pickups
        for i in powerUpEntities.indices where !powerUpEntities[i].isCollected {
            guard powerUpEntities[i].boundingRect.intersects(playerRect) else { continue }
            collectPowerUp(at: i)
        }

        // Coin pickups
        for i in coins.indices where !coins[i].isCollected {
            guard coins[i].boundingRect.intersects(playerRect) else { continue }
            collectCoin(at: i)
        }
    }

    private func handlePlayerHitObstacle(at index: Int) {
        if player.state == .monsterTruck {
            obstacles[index].isRemoved = true
            delegate?.engine(self, requestsSound: .explosion)
            delegate?.engine(self, requestsHaptic: .collision)
            return
        }
        guard !player.isInvincible else { return }

        let type = obstacles[index].type
        obstacles[index].isRemoved = true

        let sound: GameSound = type.causesSpinOut ? .carSkid
            : type == .dog   ? .dogWhimper
            : type == .human ? .scream
            : .crash
        delegate?.engine(self, requestsSound: sound)
        delegate?.engine(self, requestsHaptic: .collision)

        if type == .textMessage {
            let index = Int.random(in: 0...GameConfig.maxTextMessageIndex)
            delegate?.engine(self, didTriggerTextMessageAt: index)
            // TextMessage does NOT cost a life — it's a distraction mechanic
        } else {
            loseLife()
        }
    }

    private func collectPowerUp(at index: Int) {
        powerUpEntities[index].isCollected = true
        let type = powerUpEntities[index].type
        applyPowerUp(type)
        delegate?.engine(self, requestsHaptic: .powerUpActivated)
    }

    private func applyPowerUp(_ type: PowerUpType) {
        switch type {
        case .oneUp:
            guard player.lives < GameConfig.maxLifeCount else { return }
            player.lives += 1
            delegate?.engine(self, didUpdateLives: player.lives)
            delegate?.engine(self, requestsHaptic: .lifeGained)

        case .monsterTruck:
            player.state = .monsterTruck
            player.size  = GameConfig.monsterTruckSize
            setActivePowerUp(.monsterTruck, duration: GameConfig.monsterTruckDuration)
            delegate?.engine(self, didChangePlayerState: .monsterTruck)
            delegate?.engine(self, requestsSound: .rampage)

        case .booze:
            player.state = .drunk
            setActivePowerUp(.booze, duration: GameConfig.boozeDuration)
            delegate?.engine(self, didChangePlayerState: .drunk)

        case .wrap:
            setActivePowerUp(.wrap, duration: GameConfig.wrapDuration)

        case .multiplier(let value):
            setActivePowerUp(.multiplier(value), duration: GameConfig.multiplierDuration)
        }
    }

    private func setActivePowerUp(_ type: PowerUpType, duration: Double) {
        let state = PowerUpState(type: type, remainingSeconds: duration, totalSeconds: duration)
        activePowerUp = state
        delegate?.engine(self, didActivatePowerUp: state)
    }

    private func collectCoin(at index: Int) {
        coins[index].isCollected = true
        let multiplier: Int
        if case .multiplier(let v) = activePowerUp?.type { multiplier = v } else { multiplier = 1 }
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
            loopTask?.cancel()
            loopTask = nil
            delegate?.engineDidEnd(self, finalScore: score, moneyEarned: money)
            return
        }

        // Enter recovery: player is briefly invincible
        player.state = .recovering
        delegate?.engine(self, didChangePlayerState: .recovering)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(GameConfig.recoveryDuration))
            guard let self, self.state == .playing,
                  self.player.state == .recovering else { return }
            self.player.state = .normal
            self.delegate?.engine(self, didChangePlayerState: .normal)
        }
    }

    // MARK: - Spawn ticks

    private func tickObstacleSpawn(dt: Double) {
        obstacleSpawnAccumulator += dt
        guard obstacleSpawnAccumulator >= currentObstacleInterval else { return }
        obstacleSpawnAccumulator = 0
        spawnObstacle()
    }

    private func tickEnvironmentSpawn(dt: Double) {
        envSpawnAccumulator += dt
        guard envSpawnAccumulator >= GameConfig.environmentSpawnInterval else { return }
        envSpawnAccumulator = 0
        // Environment objects (decorative plants, coin patterns) notified via
        // the rendering layer; the pure engine does not spawn them.
    }

    private func tickPowerUpSpawn(dt: Double) {
        powerUpSpawnAccumulator += dt
        guard powerUpSpawnAccumulator >= GameConfig.powerUpSpawnInterval else { return }
        powerUpSpawnAccumulator = 0
        spawnPowerUp()
    }

    private func tickSpeedRamp(dt: Double) {
        speedRampAccumulator += dt
        guard speedRampAccumulator >= GameConfig.speedRampInterval else { return }
        speedRampAccumulator = 0
        currentObstacleInterval = max(
            currentObstacleInterval - GameConfig.speedRampStep,
            GameConfig.minObstacleInterval
        )
    }

    private func tickScore(dt: Double) {
        scoreAccumulator += GameConfig.scoreRatePerSecond * dt
        let earned = Int(scoreAccumulator)
        guard earned > 0 else { return }
        scoreAccumulator -= Double(earned)
        score += earned
        delegate?.engine(self, didUpdateScore: score)
    }

    // MARK: - Spawn helpers

    private func spawnObstacle() {
        guard let type = weightedRandom(GameConfig.obstacleWeights) else { return }
        let spawnY = worldSize.height / 2 + type.size.height / 2
        let spawnX = randomSpawnX(for: type)
        let speed  = currentObstacleSpeed

        var dx = 0.0
        if type == .movingCar {
            // Diagonal lateral drift mirroring legacy behaviour
            dx = Double.random(in: -speed * 0.25 ... speed * 0.25)
        }

        obstacles.append(ObstacleEntity(
            id: UUID(),
            position: CGPoint(x: spawnX, y: spawnY),
            size:     type.size,
            velocity: CGVector(dx: dx, dy: -speed),
            type:     type
        ))
    }

    private func spawnPowerUp() {
        let allTypes: [PowerUpType] = [
            .wrap, .oneUp, .multiplier(2), .multiplier(3), .monsterTruck, .booze
        ]
        guard let type = allTypes.randomElement() else { return }
        let spawnY = worldSize.height / 2 + GameConfig.powerUpSize.height / 2
        let halfW  = worldSize.width / 2
        let spawnX = Double.random(in: -halfW ... halfW)

        powerUpEntities.append(PowerUpEntity(
            id:       UUID(),
            position: CGPoint(x: spawnX, y: spawnY),
            size:     GameConfig.powerUpSize,
            velocity: CGVector(dx: 0, dy: -currentObstacleSpeed),
            type:     type
        ))
    }

    private func randomSpawnX(for type: ObstacleType) -> Double {
        let halfW = worldSize.width / 2
        switch type {
        case .pothole, .blackIce:
            let r = halfW * GameConfig.centralSpawnHalfFraction
            return Double.random(in: -r ... r)
        case .textMessage:
            let r = halfW * GameConfig.phoneSpawnHalfFraction
            return Double.random(in: -r ... r)
        case .plant:
            let x = halfW * GameConfig.plantSpawnFraction
            return Bool.random() ? x : -x
        case .dog, .human:
            return Double.random(in: -halfW ... halfW)
        default:
            return Double.random(in: -halfW * 0.4 ... halfW * 0.4)
        }
    }

    /// Pixels per second obstacles travel at the current speed setting.
    private var currentObstacleSpeed: Double {
        worldSize.height / currentObstacleInterval
    }

    // MARK: - Weighted random

    private func weightedRandom<T>(_ pool: [(T, Int)]) -> T? {
        let total = pool.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0 ..< total)
        for (item, weight) in pool {
            roll -= weight
            if roll < 0 { return item }
        }
        return pool.last?.0
    }

    // MARK: - Off-screen pruning

    private func pruneOffScreen() {
        let minY = -worldSize.height / 2
        obstacles.removeAll      { $0.isOffScreen(worldMinY: minY) || $0.isRemoved }
        powerUpEntities.removeAll { $0.isOffScreen(worldMinY: minY) || $0.isCollected }
        coins.removeAll           { $0.isOffScreen(worldMinY: minY) || $0.isCollected }
    }

    // MARK: - State reset

    private func resetState(carSkin: CarSkin) {
        score    = 0
        money    = 0
        obstacles.removeAll()
        powerUpEntities.removeAll()
        coins.removeAll()
        activePowerUp               = nil
        currentObstacleInterval     = GameConfig.startObstacleInterval
        obstacleSpawnAccumulator    = 0
        envSpawnAccumulator         = 0
        powerUpSpawnAccumulator     = 0
        speedRampAccumulator        = 0
        scoreAccumulator            = 0
        horizontalInput             = 0
        player = GameEngine.makePlayer(worldSize: worldSize, skin: carSkin)
    }

    private static func makePlayer(worldSize: CGSize, skin: CarSkin) -> PlayerEntity {
        let startY = -worldSize.height / 2
                   + GameConfig.playerSize.height / 2
                   + GameConfig.playerBottomMargin
        return PlayerEntity(
            position: CGPoint(x: 0, y: startY),
            velocity: .zero,
            size:     GameConfig.playerSize,
            state:    .normal,
            carSkin:  skin,
            lives:    GameConfig.beginningLifeCount
        )
    }
}
