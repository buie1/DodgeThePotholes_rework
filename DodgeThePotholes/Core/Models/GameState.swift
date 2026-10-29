import Foundation

/// Top-level lifecycle state of the game engine.
enum GameState: Equatable {
    /// Engine created but `start()` not yet called.
    case idle
    /// Active simulation running.
    case playing
    /// Simulation suspended (pause menu).
    case paused
    /// All lives exhausted; loop stopped.
    case gameOver
}
