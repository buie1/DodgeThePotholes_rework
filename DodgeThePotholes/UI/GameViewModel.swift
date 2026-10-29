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
/// - Delegates audio, haptics, and score persistence to injected services.
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
    private(set) var activePowerUp: PowerUpState? = nil
    private(set) var isDrunkMode: Bool = false

    /// Non-nil while the text-message (rickroll) overlay should be visible.
    private(set) var textMessageIndex: Int? = nil

    // MARK: - Game-over snapshot

    private(set) var finalScore: Int     = 0
    private(set) var finalMoney: Int     = 0
    private(set) var isNewHighScore: Bool = false

    // MARK: - Engine reference (read by GameView Canvas for rendering)

    private(set) var engine: GameEngine?

    // MARK: - Services

    private let audioService:  any AudioServiceProtocol
    private let hapticService: any HapticServiceProtocol
    private let scoreService:  any ScoreServiceProtocol

    /// Background music tracks that can be randomly selected on game start.
    /// The user's chosen track will be wired here in the Settings phase.
    private static let musicTracks: [GameSound] = [
        .hotPursuit, .bornLucky, .raceDuel, .catchMe, .urbanChase,
    ]

    // MARK: - Init

    /// Creates the view model with concrete service defaults.
    /// Pass mock implementations in tests or Previews.
    init(
        audio:  any AudioServiceProtocol  = AudioService(),
        haptics: any HapticServiceProtocol = HapticService(),
        scores:  any ScoreServiceProtocol  = UserDefaultsScoreService()
    ) {
        self.audioService  = audio
        self.hapticService = haptics
        self.scoreService  = scores
        highScore = scores.highScore
    }

    // MARK: - Lifecycle

    /// Transition to the game screen without starting the engine.
    /// `GameView.onAppear` calls `startGame(worldSize:)` once it knows the canvas size.
    func navigateToGame() {
        route = .playing
    }

    /// Start (or restart) a new game session.
    /// - Parameter worldSize: The logical canvas size in points, from `GeometryReader`.
    /// - Parameter carSkin: The player's currently selected car skin.
    func startGame(worldSize: CGSize, carSkin: CarSkin = .blue) {
        let eng = GameEngine(worldSize: worldSize, carSkin: carSkin)
        eng.delegate = self
        engine = eng

        // Reset HUD
        score            = 0
        money            = 0
        lives            = GameConfig.beginningLifeCount
        activePowerUp    = nil
        isDrunkMode      = false
        textMessageIndex = nil
        playerState      = .normal
        route            = .playing

        // Audio: start a random music track then play the game-start SFX.
        let track = Self.musicTracks.randomElement() ?? .hotPursuit
        audioService.startMusic(track)
        audioService.play(.gameStart)

        eng.start(carSkin: carSkin)
    }

    func pauseGame() {
        engine?.pause()
    }

    func resumeGame() {
        engine?.resume()
    }

    /// Called from `GameOverView` "Main Menu" button.
    func returnToMenu() {
        engine?.forceStop()
        engine = nil
        audioService.stopMusic()
        route  = .mainMenu
    }

    // MARK: - Input

    /// Forward normalised horizontal input [-1, 1] to the engine.
    /// Positive = right. Called from `DragGesture.onChanged`.
    func setHorizontalInput(_ value: Double) {
        engine?.setHorizontalInput(value)
    }

    /// Stop lateral movement. Called from `DragGesture.onEnded`.
    func stopHorizontalInput() {
        engine?.setHorizontalInput(0)
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
        isDrunkMode = (state == .drunk)
        audioService.setDrunkMode(isDrunkMode)
    }

    func engine(_ engine: GameEngine, didActivatePowerUp powerUp: PowerUpState) {
        activePowerUp = powerUp
    }

    func engine(_ engine: GameEngine, didDeactivatePowerUp type: PowerUpType) {
        activePowerUp = nil
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

        isNewHighScore = scoreService.save(score: finalScore)
        highScore      = scoreService.highScore

        audioService.stopMusic()
        route = .gameOver
    }

    func engine(_ engine: GameEngine, requestsSound sound: GameSound) {
        audioService.play(sound)
    }

    func engine(_ engine: GameEngine, requestsHaptic pattern: HapticPattern) {
        hapticService.play(pattern)
    }
}
