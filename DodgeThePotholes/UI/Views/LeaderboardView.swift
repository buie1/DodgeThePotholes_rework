import SwiftUI

/// Your best score above a ranked top 10. Replaces the legacy `Highscore` scene.
struct LeaderboardView: View {

    let viewModel: LeaderboardViewModel

    var body: some View {
        MenuScreen("LEADERBOARD", titleColor: .cyan) {
            VStack(spacing: 20) {
                bestCard

                ScrollView {
                    rows
                        .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.load() }

                if case .offline(let reason) = viewModel.source {
                    Text(reason)
                        .font(.pixel(7))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                if viewModel.canShowDashboard {
                    MenuButton(title: "GAME CENTER", color: .cyan) {
                        viewModel.showDashboard()
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Sub-views

    private var bestCard: some View {
        HStack {
            Text("YOUR BEST")
                .font(.pixel(10))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("\(viewModel.localHighScore)")
                .font(.pixel(16))
                .foregroundStyle(.yellow)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var rows: some View {
        if viewModel.source == .loading {
            ProgressView()
                .tint(.cyan)
                .padding(.top, 40)
        } else if viewModel.entries.isEmpty {
            Text("PLAY A GAME TO GET ON THE BOARD")
                .font(.pixel(9))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.entries) { entry in
                    LeaderboardRow(entry: entry)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(viewModel: LeaderboardViewModel(
            persistence: SwiftDataPersistenceService.inMemory(),
            leaderboard: GameCenterLeaderboardService()
        ))
    }
}
