import XCTest
@testable import DodgeThePotholes

/// Game Center top scores when signed in; the player's own best runs otherwise.
@MainActor
final class LeaderboardViewModelTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var leaderboard: MockLeaderboardService!
    private var viewModel: LeaderboardViewModel!

    private let globalEntries = [
        LeaderboardEntry(rank: 1, playerName: "Speedy", score: 9_000, isLocalPlayer: false),
        LeaderboardEntry(rank: 2, playerName: "Me", score: 4_000, isLocalPlayer: true),
    ]

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        leaderboard = MockLeaderboardService()
        viewModel = LeaderboardViewModel(persistence: persistence, leaderboard: leaderboard)
        for score in [300, 800, 500] {
            persistence.recordRun(score: score, moneyEarned: 0)
        }
    }

    func testStartsLoading() {
        XCTAssertEqual(viewModel.source, .loading)
        XCTAssertEqual(viewModel.localHighScore, 800)
    }

    func testSignedInShowsGameCenterScores() async {
        leaderboard.isAuthenticated = true
        leaderboard.entries = globalEntries

        await viewModel.load()

        XCTAssertEqual(viewModel.source, .gameCenter)
        XCTAssertEqual(viewModel.entries, globalEntries)
        XCTAssertTrue(viewModel.canShowDashboard)
    }

    func testSignedOutShowsOwnRunsWithSignInReason() async {
        await viewModel.load()

        XCTAssertEqual(viewModel.source, .offline(reason: LeaderboardViewModel.signInReason))
        XCTAssertEqual(viewModel.entries.map(\.score), [800, 500, 300])
        XCTAssertEqual(viewModel.entries.map(\.rank), [1, 2, 3])
        XCTAssertTrue(viewModel.entries.allSatisfy(\.isLocalPlayer))
        XCTAssertFalse(viewModel.canShowDashboard)
    }

    func testFetchErrorFallsBackToOwnRuns() async {
        leaderboard.isAuthenticated = true
        leaderboard.error = LeaderboardError.leaderboardNotFound

        await viewModel.load()

        XCTAssertEqual(viewModel.source, .offline(reason: LeaderboardViewModel.unreachableReason))
        XCTAssertEqual(viewModel.entries.map(\.score), [800, 500, 300])
    }

    func testNoRunsGivesEmptyBoard() async {
        let fresh = LeaderboardViewModel(persistence: MockPersistenceService(), leaderboard: leaderboard)
        await fresh.load()

        XCTAssertTrue(fresh.entries.isEmpty)
        XCTAssertEqual(fresh.source, .offline(reason: LeaderboardViewModel.signInReason))
    }

    func testShowDashboardOpensGameCenter() {
        viewModel.showDashboard()
        XCTAssertTrue(leaderboard.dashboardShown)
    }
}
