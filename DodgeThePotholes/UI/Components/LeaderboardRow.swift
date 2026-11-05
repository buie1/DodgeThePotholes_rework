import SwiftUI

/// One ranked leaderboard line. The player's own entries are yellow, as in the legacy screen.
struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank).")
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.5))
            Text(entry.playerName.uppercased())
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text("\(entry.score)")
        }
        .font(.pixel(10))
        .foregroundStyle(entry.isLocalPlayer ? .yellow : .white)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.playerName), \(entry.score)")
    }
}

#Preview {
    VStack {
        LeaderboardRow(entry: LeaderboardEntry(rank: 1, playerName: "Speedy", score: 48_210, isLocalPlayer: false))
        LeaderboardRow(entry: LeaderboardEntry(rank: 2, playerName: "You", score: 31_007, isLocalPlayer: true))
    }
    .padding()
    .background(.black)
}
