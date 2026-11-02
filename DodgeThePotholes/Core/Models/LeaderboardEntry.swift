import Foundation

/// One row on the leaderboard: a Game Center score, or one of the player's own runs offline.
struct LeaderboardEntry: Identifiable, Equatable {
    let rank: Int
    let playerName: String
    let score: Int
    /// `true` for the signed-in player's entry (and every offline entry); shown in yellow.
    let isLocalPlayer: Bool

    var id: Int { rank }
}
