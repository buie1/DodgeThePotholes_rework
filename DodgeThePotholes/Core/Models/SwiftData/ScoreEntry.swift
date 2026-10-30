import Foundation
import SwiftData

/// One finished run, kept as local history and as an offline leaderboard fallback.
@Model
final class ScoreEntry {
    var score: Int
    var moneyEarned: Int
    var date: Date

    init(score: Int, moneyEarned: Int, date: Date = .now) {
        self.score = score
        self.moneyEarned = moneyEarned
        self.date = date
    }
}
