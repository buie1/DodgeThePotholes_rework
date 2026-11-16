import SwiftUI

/// Four tiles summing up a run: time survived, coins, near-misses and best combo.
struct RunStatsGrid: View {
    let time: Double
    let stats: RunStats

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                tile("TIME", Self.clock(time), color: .white)
                tile("COINS", "\(stats.coins)", color: .green)
            }
            GridRow {
                tile("NEAR MISSES", "\(stats.nearMisses)", color: .yellow)
                tile("BEST COMBO", "x\(stats.bestMultiplier)", color: .orange)
            }
        }
    }

    /// `m:ss`, e.g. `1:07`.
    static func clock(_ seconds: Double) -> String {
        let whole = Int(seconds)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func tile(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.pixel(8))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.pixel(14))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RunStatsGrid(time: 83, stats: RunStats(coins: 54, smashed: 4, scared: 3, powerUps: 2, nearMisses: 11, bestMultiplier: 3))
        .padding()
        .background(.black)
}
