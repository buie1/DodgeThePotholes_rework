import Foundation

// MARK: - Protocol

/// Persists and retrieves the local high score.
///
/// The protocol boundary allows a future SwiftData implementation to be
/// swapped in without changing `GameViewModel`.
protocol ScoreServiceProtocol: AnyObject {
    /// The current high score loaded from persistent storage.
    var highScore: Int { get }

    /// Compares `score` against the stored high score.
    /// Persists and updates `highScore` only when `score` is strictly greater.
    /// - Returns: `true` when a new high score was set.
    @discardableResult
    func save(score: Int) -> Bool

    /// Wipes the stored high score back to zero (used for testing / reset).
    func reset()
}

// MARK: - UserDefaults implementation

/// `UserDefaults`-backed score persistence.
///
/// Uses the same `"highscore"` key as the legacy codebase so existing saved
/// scores survive the rewrite without a migration step.
final class UserDefaultsScoreService: ScoreServiceProtocol {

    private static let key = "highscore"

    private(set) var highScore: Int

    init() {
        highScore = UserDefaults.standard.integer(forKey: Self.key)
    }

    @discardableResult
    func save(score: Int) -> Bool {
        guard score > highScore else { return false }
        highScore = score
        UserDefaults.standard.set(score, forKey: Self.key)
        return true
    }

    func reset() {
        highScore = 0
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
