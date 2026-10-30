import XCTest
@testable import DodgeThePotholes

/// The game uses saved progress: car, song, sound settings, extra life, tank, and banking.
@MainActor
final class GameViewModelPersistenceTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var audio: MockAudioService!
    private var viewModel: GameViewModel!

    private let screen = CGSize(width: 402, height: 874)

    override func setUp() {
        super.setUp()
        persistence = MockPersistenceService()
        audio = MockAudioService()
        viewModel = GameViewModel(persistence: persistence, audio: audio,
                                  haptics: MockHapticService(), motion: MockMotionService())
    }

    func testUsesSelectedCarAndSong() {
        persistence.selectedCar = .green
        persistence.selectedSong = .catchMe
        viewModel.startGame(screenSize: screen)

        XCTAssertEqual(viewModel.engine?.player.carSkin, .green)
        XCTAssertEqual(audio.startedTrack, .catchMe)
    }

    func testAppliesSoundSettings() {
        persistence.isMusicEnabled = false
        persistence.isSFXEnabled = false
        viewModel.startGame(screenSize: screen)

        XCTAssertFalse(audio.isMusicEnabled)
        XCTAssertFalse(audio.isSFXEnabled)
    }

    func testExtraLifeIsUsedForOneRunOnly() {
        persistence.extraLifePending = true
        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.lives, GameConfig.beginningLifeCount + 1)
        XCTAssertEqual(viewModel.engine?.player.lives, GameConfig.beginningLifeCount + 1)
        XCTAssertFalse(persistence.extraLifePending)

        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.lives, GameConfig.beginningLifeCount)
    }

    func testTankIsPassedToThePlayer() {
        persistence.hasTank = true
        viewModel.startGame(screenSize: screen)
        XCTAssertEqual(viewModel.engine?.player.hasTank, true)
    }

    func testGameOverBanksMoneyAndRecordsHighScore() {
        persistence.money = 100
        persistence.highScore = 50
        viewModel.startGame(screenSize: screen)

        viewModel.engineDidEnd(viewModel.engine!, finalScore: 80, moneyEarned: 25)

        XCTAssertEqual(persistence.money, 125)
        XCTAssertTrue(viewModel.isNewHighScore)
        XCTAssertEqual(viewModel.highScore, 80)
        XCTAssertEqual(viewModel.route, .gameOver)
    }
}
