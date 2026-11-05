import Foundation
import CoreGraphics
import Observation

// MARK: - App-level route

/// Top-level navigation state managed by `GameViewModel`.
/// Replaces the legacy SKScene-to-SKScene `presentScene(_:)` pattern.
enum AppRoute: Equatable {
    case mainMenu
    case playing
    case gameOver
}

// MARK: - GameViewModel

/// `@Observable` bridge between `GameEngine` and the SwiftUI layer.
///
/// **Responsibilities**
/// - Creates, owns, and drives `GameEngine`.
/// - Conforms to `GameEngineDelegate` to receive event callbacks.
/// - Exposes observable state consumed by `GameView`'s HUD and `GameOverView`.
/// - Routes horizontal input (drag gesture / accelerometer) to the engine.
/// - Delegates audio, haptics, and saved progress to injected services.
@Observable
@MainActor
final class GameViewModel: GameEngineDelegate {

    // MARK: - Route

    private(set) var route: AppRoute = .mainMenu

    /// Convenience accessor used to present `GameView` as a full-screen cover.
    /// The setter is called when the cover is dismissed externally (e.g. swipe-down);
    /// it delegates to `returnToMenu()` so engine state is always cleaned up.
    var isShowingGame: Bool {
        get { route == .playing || route == .gameOver }
        set { if !newValue { returnToMenu() } }
    }

    // MARK: - HUD state (updated via delegate callbacks)

    private(set) var score: Int  = 0
    private(set) var money: Int  = 0
    private(set) var lives: Int  = GameConfig.beginningLifeCount
    private(set) var highScore: Int
    private(set) var playerState: PlayerState = .normal
    private(set) var isDrunkMode: Bool = false

    /// The most recently activated timed power-up still running, read live from
    /// the engine so its countdown stays current.
    var activePowerUp: PowerUpState? { engine?.activePowerUps.last }

    /// Banner currently flying across the screen, or `nil`.
    private(set) var activeAlert: GameAlert? = nil

    /// Non-nil while the text-message (rickroll) overlay should be visible.
    private(set) var textMessageIndex: Int? = nil

    // MARK: - Game-over snapshot

    private(set) var finalScore: Int     = 0
    private(set) var finalMoney: Int     = 0
    private(set) var isNewHighScore: Bool = false

    // MARK: - Engine & renderer

    private(set) var engine: GameEngine?

    /// SpriteKit scene that draws `engine` and drives its clock; shown by `GameView`.
    private(set) var scene: GameRenderScene?

    /// Music track for this run; restored after monster-truck mode.
    private var currentTrack: GameSound = .hotPursuit

    // MARK: - Services

    private let audioService:  any AudioServiceProtocol
    private let hapticService: any HapticServiceProtocol
    private let persistence:   any PersistenceServiceProtocol
    private let motionService: any MotionServiceProtocol
    private let leaderboard:   any LeaderboardServiceProtocol

    // MARK: - Steering input

    /// Latest tilt steering in [-1, 1]; `0` when no accelerometer.
    private var tiltInput: Double = 0
    /// Drag steering while a finger is down; overrides tilt. `nil` when not dragging.
    private var dragInput: Double? = nil

    // MARK: - Init

    /// Creates the view model with concrete service defaults.
    /// Pass mock implementations in tests or Previews.
    /// - Parameters:
    ///   - persistence: Saved progress; supplies the car, song, sound
    ///     settings and shop upgrades, and banks each run's earnings.
    ///   - leaderboard: Receives each finished run's score.
    init(
        persistence: any PersistenceServiceProtocol,
        audio:  any AudioServiceProtocol  = AudioService(),
        haptics: any HapticServiceProtocol = HapticService(),
        motion:  any MotionServiceProtocol = MotionService(),
        leaderboard: any LeaderboardServiceProtocol = GameCenterLeaderboardService()
    ) {
        self.persistence   = persistence
        self.audioService  = audio
        self.hapticService = haptics
        self.motionService = motion
        self.leaderboard   = leaderboard
        highScore = persistence.highScore
    }

    // MARK: - Lifecycle

    /// Transition to the game screen without starting the engine.
    /// `GameView.onAppear` calls `startGame(worldSize:)` once it knows the canvas size.
    func navigateToGame() {
        route = .playing
    }

    /// Start (or restart) a new game session.
    /// Uses the saved car, song and sound settings, and spends a bought extra life.
    /// - Parameter screenSize: The on-screen canvas size in points, from `GeometryReader`.
    ///   It is converted to the 750-unit-wide game world.
    func startGame(screenSize: CGSize) {
        let carSkin = persistence.selectedCar
        let worldSize = GameConfig.worldSize(forScreen: screenSize)
        let eng = GameEngine(worldSize: worldSize, carSkin: carSkin, drivesOwnLoop: false)
        eng.delegate = self
        engine = eng
        scene = GameRenderScene(engine: eng)

        // Reset HUD
        score            = 0
        money            = 0
        lives            = GameConfig.beginningLifeCount
        isDrunkMode      = false
        textMessageIndex = nil
        activeAlert      = nil
        playerState      = .normal
        route            = .playing

        // Audio: apply saved settings, start the chosen track, then the game-start SFX.
        audioService.isMusicEnabled = persistence.isMusicEnabled
        audioService.isSFXEnabled   = persistence.isSFXEnabled
        currentTrack = persistence.selectedSong
        audioService.startMusic(currentTrack)
        audioService.play(.gameStart)

        tiltInput = 0
        dragInput = nil
        motionService.start { [weak self] tilt in
            self?.tiltInput = tilt
            self?.applySteering()
        }

        let extraLives = persistence.consumeExtraLife() ? 1 : 0
        eng.start(carSkin: carSkin, extraLives: extraLives, hasTank: persistence.hasTank)
        lives = eng.player.lives
    }

    func pauseGame() {
        engine?.pause()
        scene?.isPaused = true
    }

    func resumeGame() {
        engine?.resume()
        scene?.isPaused = false
    }

    /// Called from `GameOverView` "Main Menu" button.
    func returnToMenu() {
        engine?.forceStop()
        engine = nil
        scene  = nil
        motionService.stop()
        audioService.stopMusic()
        route  = .mainMenu
    }

    // MARK: - Input

    /// `true` when tilting the device steers the car.
    var isTiltAvailable: Bool { motionService.isAvailable }

    /// Drag steering in [-1, 1] while a finger is down (positive = right).
    /// Overrides tilt until `endDrag(wasTap:)`. Called from `DragGesture.onChanged`.
    func updateDrag(_ value: Double) {
        dragInput = max(-1, min(1, value))
        applySteering()
    }

    /// Ends drag steering and hands control back to tilt.
    /// A touch that barely moved is a tap, which sounds the horn.
    func endDrag(wasTap: Bool) {
        dragInput = nil
        applySteering()
        if wasTap { honk() }
    }

    /// Sound the horn (or fire a missile in monster-truck mode).
    func honk() {
        engine?.honk()
    }

    private func applySteering() {
        engine?.setHorizontalInput(dragInput ?? tiltInput)
    }

    // MARK: - GameEngineDelegate

    func engine(_ engine: GameEngine, didUpdateScore score: Int) {
        self.score = score
    }

    func engine(_ engine: GameEngine, didUpdateMoney money: Int) {
        self.money = money
    }

    func engine(_ engine: GameEngine, didUpdateLives lives: Int) {
        self.lives = lives
    }

    func engine(_ engine: GameEngine, didChangePlayerState state: PlayerState) {
        playerState = state
    }

    func engine(_ engine: GameEngine, didActivatePowerUp powerUp: PowerUpState) {
        switch powerUp.type {
        case .booze:
            isDrunkMode = true
            audioService.setDrunkMode(true)
        case .monsterTruck:
            // Legacy swapped the background music for the monster-truck theme.
            audioService.stopMusic()
            audioService.play(.rampage)
            audioService.play(.monsterTruck)
        default:
            break
        }
    }

    func engine(_ engine: GameEngine, didDeactivatePowerUp type: PowerUpType) {
        switch type {
        case .booze:
            isDrunkMode = false
            audioService.setDrunkMode(false)
        case .monsterTruck:
            audioService.startMusic(currentTrack)
        default:
            break
        }
    }

    func engine(_ engine: GameEngine, didRaiseAlert alert: GameAlert) {
        activeAlert = alert
        // Auto-dismiss after the fly-in / hold / fly-out sequence.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.activeAlert == alert { self?.activeAlert = nil }
        }
    }

    func engine(_ engine: GameEngine, didTriggerTextMessageAt index: Int) {
        textMessageIndex = index
        // Auto-dismiss after 3 seconds.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.textMessageIndex == index { self?.textMessageIndex = nil }
        }
    }

    func engineDidEnd(_ engine: GameEngine, finalScore: Int, moneyEarned: Int) {
        self.finalScore = finalScore
        self.finalMoney = moneyEarned

        isNewHighScore = persistence.recordRun(score: finalScore, moneyEarned: moneyEarned)
        highScore      = persistence.highScore

        // Every run is submitted; Game Center keeps each player's best.
        Task { [leaderboard] in await leaderboard.submit(score: finalScore) }

        audioService.stopMusic()
        motionService.stop()
        route = .gameOver
    }

    func engine(_ engine: GameEngine, requestsSound sound: GameSound) {
        audioService.play(sound)
    }

    func engine(_ engine: GameEngine, requestsHaptic pattern: HapticPattern) {
        hapticService.play(pattern)
    }
}
