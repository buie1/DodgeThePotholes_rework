import XCTest
@testable import DodgeThePotholes

/// Who gets the tutorial, and a full playthrough of its four steps.
@MainActor
final class TutorialTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var viewModel: GameViewModel!

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        persistence.tutorialStatus = .new
        viewModel = GameViewModel(persistence: persistence, audio: MockAudioService(), haptics: MockHapticService(),
                                  motion: MockMotionService(), leaderboard: MockLeaderboardService())
    }

    private func play(_ seconds: Double) {
        for _ in 0..<Int(seconds * 60) { viewModel.engine?.update(deltaTime: 1.0 / 60) }
    }

    // MARK: - Who gets it

    func testNewPlayersRequestsAndVeteransSkip() {
        XCTAssertTrue(persistence.needsTutorial, "a brand-new player")
        persistence.recordRun(score: 100, moneyEarned: 0)
        XCTAssertFalse(persistence.needsTutorial, "players with runs already know the game")
        persistence.tutorialStatus = .requested
        XCTAssertTrue(persistence.needsTutorial, "unless they ask to replay it")
        persistence.tutorialStatus = .done
        XCTAssertFalse(persistence.needsTutorial)
    }

    func testTutorialRunIsAnEmptyPracticeRoad() {
        persistence.extraLifePending = true
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
        XCTAssertNotNil(viewModel.tutorial)
        XCTAssertTrue(viewModel.engine!.isPractice)
        XCTAssertTrue(persistence.extraLifePending, "a bought extra life waits for a real run")

        viewModel.engine?.setHorizontalInput(0)
        play(1)   // still on the steer step: nothing placed, nothing random
        XCTAssertTrue(viewModel.engine!.obstacles.isEmpty)
    }

    // MARK: - Playthrough

    func testFullPlaythroughThenRealRun() {
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
        let engine = viewModel.engine!
        XCTAssertEqual(viewModel.tutorial?.step, .steer)

        engine.setHorizontalInput(1);  play(0.5)
        engine.setHorizontalInput(-1); play(1)
        XCTAssertEqual(viewModel.tutorial?.step, .honk)
        engine.setHorizontalInput(1);  play(0.4)   // back from the verge to the middle
        engine.setHorizontalInput(0)
        XCTAssertLessThan(abs(engine.player.position.x), Tutorial.roadReach)

        play(Tutorial.readTime + 0.1)
        XCTAssertTrue(engine.obstacles.contains { $0.type == .dog }, "a dog is placed ahead")
        engine.honk()
        play(1.2)
        XCTAssertEqual(viewModel.tutorial?.step, .coins)

        play(Tutorial.readTime + 2.5)          // coins drop straight onto the car
        XCTAssertEqual(viewModel.tutorial?.step, .powerUp)

        play(Tutorial.readTime + 2.5)          // so does the power-up
        XCTAssertEqual(viewModel.tutorial?.step, .done)
        XCTAssertEqual(engine.player.lives, GameTuning.bundled.lives.start)

        viewModel.finishTutorial()
        XCTAssertEqual(persistence.tutorialStatus, .done)
        XCTAssertNil(viewModel.tutorial)
        XCTAssertFalse(viewModel.engine!.isPractice, "the real run")
    }

    func testPromptsMatchTheControls() {
        XCTAssertEqual(Tutorial(controls: .tilt).prompt, "TILT THE PHONE LEFT AND RIGHT")
        XCTAssertEqual(Tutorial(controls: .drag).prompt, "DRAG LEFT AND RIGHT TO STEER")
    }

    func testTutorialRunsAreNeverRecorded() {
        viewModel.startGame(screenSize: CGSize(width: 402, height: 874))
        viewModel.engineDidEnd(viewModel.engine!, finalScore: 999, moneyEarned: 5)
        XCTAssertTrue(persistence.runs.isEmpty)
    }
}
