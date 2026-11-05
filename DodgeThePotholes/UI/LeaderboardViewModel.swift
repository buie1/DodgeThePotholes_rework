import Foundation
import Observation

/// Where the leaderboard's entries came from.
enum LeaderboardSource: Equatable {
    case loading
    case gameCenter
    /// Showing the player's own best runs; `reason` explains why.
    case offline(reason: String)
}

/// `@Observable` state for the Leaderboard screen. Replaces the legacy `Highscore` scene.
///
/// Shows the Game Center global top 10 when signed in, and otherwise falls back
/// to the player's own best runs from the local score history.
@Observable
@MainActor
final class LeaderboardViewModel {

    static let limit = 10
    static let signInReason = "SIGN IN TO GAME CENTER TO SEE GLOBAL SCORES"
    static let unreachableReason = "COULDN'T REACH GAME CENTER"

    private(set) var entries: [LeaderboardEntry] = []
    private(set) var source: LeaderboardSource = .loading

    private let persistence: any PersistenceServiceProtocol
    private let leaderboard: any LeaderboardServiceProtocol

    init(persistence: any PersistenceServiceProtocol, leaderboard: any LeaderboardServiceProtocol) {
        self.persistence = persistence
        self.leaderboard = leaderboard
    }

    /// The player's saved high score.
    var localHighScore: Int { persistence.highScore }

    /// `true` when Apple's Game Center dashboard can be opened.
    var canShowDashboard: Bool { leaderboard.isAuthenticated }

    /// Loads the global top scores, or the player's own runs when Game Center is unavailable.
    func load() async {
        // Keep the current rows on screen while refreshing.
        if entries.isEmpty { source = .loading }

        guard leaderboard.isAuthenticated else {
            showLocalRuns(reason: Self.signInReason)
            return
        }
        do {
            entries = try await leaderboard.topScores(limit: Self.limit)
            source = .gameCenter
        } catch {
            showLocalRuns(reason: Self.unreachableReason)
        }
    }

    func showDashboard() {
        leaderboard.showDashboard()
    }

    private func showLocalRuns(reason: String) {
        entries = persistence.bestRuns(limit: Self.limit).enumerated().map { index, run in
            LeaderboardEntry(rank: index + 1, playerName: "YOU", score: run.score, isLocalPlayer: true)
        }
        source = .offline(reason: reason)
    }
}
