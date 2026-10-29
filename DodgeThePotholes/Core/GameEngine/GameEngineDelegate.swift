import Foundation

/// Callback interface from `GameEngine` to the presentation layer.
///
/// All methods are called on the `@MainActor` so conforming types
/// (typically `GameViewModel`) can mutate `@Observable` properties directly.
@MainActor
protocol GameEngineDelegate: AnyObject {
    /// Fired every tick while the engine's score changes.
    func engine(_ engine: GameEngine, didUpdateScore score: Int)
    /// Fired each time a coin is collected (money total changes).
    func engine(_ engine: GameEngine, didUpdateMoney money: Int)
    /// Fired when a life is gained or lost.
    func engine(_ engine: GameEngine, didUpdateLives lives: Int)
    /// Fired when the player transitions between states (normal → recovering, etc.).
    func engine(_ engine: GameEngine, didChangePlayerState state: PlayerState)
    /// Fired when a timed power-up becomes active.
    func engine(_ engine: GameEngine, didActivatePowerUp powerUp: PowerUpState)
    /// Fired when a timed power-up expires.
    func engine(_ engine: GameEngine, didDeactivatePowerUp type: PowerUpType)
    /// Fired when the player hits a TextMessage obstacle (rickroll easter egg).
    /// `index` advances one lyric per phone and wraps after `GameConfig.textMessageCount`.
    func engine(_ engine: GameEngine, didTriggerTextMessageAt index: Int)
    /// Fired when a banner message should fly across the screen.
    func engine(_ engine: GameEngine, didRaiseAlert alert: GameAlert)
    /// Fired once when all lives reach zero.
    func engineDidEnd(_ engine: GameEngine, finalScore: Int, moneyEarned: Int)
    /// Requests an audio cue to be played by the AudioManager.
    func engine(_ engine: GameEngine, requestsSound sound: GameSound)
    /// Requests a haptic event to be played by the HapticsManager.
    func engine(_ engine: GameEngine, requestsHaptic pattern: HapticPattern)
}
