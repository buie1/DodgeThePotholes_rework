import XCTest
@testable import DodgeThePotholes

/// Pausing a run, and resuming after the 3-2-1 countdown.
@MainActor
final class PauseTests: XCTestCase {

    private var audio: MockAudioService!
    private var viewModel: GameViewModel!

    override func setUp() async throws {
        try await super.setUp()
        audio = MockAudioService()
        viewModel = GameViewModel(persistence: MockPersistenceService(), audio: audio, haptics: MockHapticService(),
                                  motion: MockMotionService(), leaderboard: MockLeaderboardService())
        viewModel.countdownStep = .milliseconds(20)
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
    }

    func testPauseFreezesTheRunAndMusic() {
        viewModel.pause()
        XCTAssertEqual(viewModel.pauseState, .paused)
        XCTAssertEqual(viewModel.engine?.state, .paused)
        XCTAssertTrue(audio.isMusicPaused)
    }

    func testResumeCountsDownThenPlays() async throws {
        viewModel.pause()
        viewModel.resumeAfterCountdown()
        XCTAssertEqual(viewModel.pauseState, .countingDown(3))
        XCTAssertEqual(viewModel.engine?.state, .paused, "still paused during the countdown")

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(viewModel.pauseState, .running)
        XCTAssertEqual(viewModel.engine?.state, .playing)
        XCTAssertFalse(audio.isMusicPaused)
    }

    func testPausingDuringTheCountdownCancelsIt() async throws {
        viewModel.pause()
        viewModel.resumeAfterCountdown()
        viewModel.pause()                       // e.g. the app went to the background again
        XCTAssertEqual(viewModel.pauseState, .paused)

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(viewModel.pauseState, .paused, "the cancelled countdown never resumes")
        XCTAssertEqual(viewModel.engine?.state, .paused)
    }

    func testPauseOnlyWhilePlaying() {
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 10, moneyEarned: 0)
        viewModel.pause()
        XCTAssertEqual(viewModel.pauseState, .running, "nothing to pause on the game-over screen")
    }

    func testNewRunAndMainMenuClearThePause() {
        viewModel.pause()
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
        XCTAssertEqual(viewModel.pauseState, .running)
        viewModel.pause()
        viewModel.returnToMenu()
        XCTAssertEqual(viewModel.pauseState, .running)
    }
}
