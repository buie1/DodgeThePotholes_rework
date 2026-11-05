import GameKit
import Observation
import UIKit

// MARK: - Protocol

/// Why the global leaderboard couldn't be loaded.
enum LeaderboardError: Error, Equatable {
    case notAuthenticated
    /// No leaderboard with `GameConfig.leaderboardID` exists in App Store Connect.
    case leaderboardNotFound
}

/// The global high-score leaderboard. Replaces the legacy Firebase top-10.
///
/// The protocol boundary keeps the game playable and testable without Game Center:
/// every method is safe to call while signed out.
@MainActor
protocol LeaderboardServiceProtocol: AnyObject {
    /// `true` once the player is signed in to Game Center.
    var isAuthenticated: Bool { get }
    /// The signed-in player's Game Center name.
    var playerName: String? { get }

    /// Signs the player in to Game Center, showing Apple's sign-in sheet if needed.
    func authenticate()

    /// Submits a finished run's score. Does nothing while signed out.
    func submit(score: Int) async

    /// The global top scores, best first.
    /// - Throws: `LeaderboardError`, or a GameKit error when Game Center can't be reached.
    func topScores(limit: Int) async throws -> [LeaderboardEntry]

    /// Opens Apple's Game Center leaderboard dashboard.
    func showDashboard()
}

// MARK: - GameKit implementation

/// Game Center–backed leaderboard.
///
/// Until the app is signed with a team and the leaderboard exists in App Store
/// Connect, sign-in fails quietly and the service stays signed out.
@Observable
@MainActor
final class GameCenterLeaderboardService: LeaderboardServiceProtocol {

    private(set) var isAuthenticated = false
    private(set) var playerName: String?

    /// Touches no GameKit state, so it can be a default argument outside the main actor.
    nonisolated init() {}

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.present(viewController)
                } else {
                    self.refreshPlayer()
                }
            }
        }
    }

    func submit(score: Int) async {
        guard isAuthenticated else { return }
        try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                             leaderboardIDs: [GameConfig.leaderboardID])
    }

    func topScores(limit: Int) async throws -> [LeaderboardEntry] {
        guard isAuthenticated else { throw LeaderboardError.notAuthenticated }
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [GameConfig.leaderboardID])
        guard let board = boards.first else { throw LeaderboardError.leaderboardNotFound }

        let (_, entries, _) = try await board.loadEntries(for: .global, timeScope: .allTime,
                                                          range: NSRange(location: 1, length: limit))
        let localID = GKLocalPlayer.local.gamePlayerID
        return entries.map {
            LeaderboardEntry(rank: $0.rank, playerName: $0.player.displayName,
                             score: $0.score, isLocalPlayer: $0.player.gamePlayerID == localID)
        }
    }

    func showDashboard() {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    // MARK: - Private

    private func refreshPlayer() {
        let player = GKLocalPlayer.local
        isAuthenticated = player.isAuthenticated
        playerName = player.isAuthenticated ? player.displayName : nil
    }

    /// Presents GameKit's sign-in sheet over whatever is on screen.
    private static func present(_ viewController: UIViewController) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}
