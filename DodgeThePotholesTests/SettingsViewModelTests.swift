import XCTest
@testable import DodgeThePotholes

/// Sound switches save through persistence; the song picker cycles owned songs only.
@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var viewModel: SettingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        persistence = MockPersistenceService()
        persistence.unlocked = [GameSound.hotPursuit.rawValue, GameSound.raceDuel.rawValue,
                                GameSound.urbanChase.rawValue]
        viewModel = SettingsViewModel(persistence: persistence)
    }

    func testControlSchemeAndCalibrationSave() {
        let motion = MockMotionService()
        let viewModel = SettingsViewModel(persistence: persistence, motion: motion)
        viewModel.controlScheme = .drag
        XCTAssertEqual(persistence.controlScheme, .drag)

        viewModel.startTiltPreview()
        motion.rawTilt = 0.25                     // the player holds the phone tipped right
        viewModel.calibrateTilt()
        XCTAssertEqual(persistence.tiltNeutral, 0.25)
        XCTAssertEqual(motion.neutralTilt, 0.25)
        XCTAssertTrue(viewModel.isTiltCalibrated)

        viewModel.resetTiltCalibration()
        XCTAssertEqual(persistence.tiltNeutral, 0)
        viewModel.stopTiltPreview()
        XCTAssertEqual(motion.stopCount, 1)
    }

    func testNewPlayersChooseControlsOnce() {
        XCTAssertTrue(viewModel.needsControlChoice)
        viewModel.chooseControls(.drag)
        XCTAssertEqual(persistence.controlScheme, .drag)
        XCTAssertFalse(viewModel.needsControlChoice, "asked once")
    }

    func testExistingPlayersSkipTheChoice() {
        persistence.recordRun(score: 100, moneyEarned: 1)
        XCTAssertFalse(viewModel.needsControlChoice, "they already know the game")
    }

    func testTogglesSaveThroughPersistence() {
        viewModel.isMusicEnabled = false
        viewModel.isSFXEnabled = false
        XCTAssertFalse(persistence.isMusicEnabled)
        XCTAssertFalse(persistence.isSFXEnabled)
    }

    func testOwnedSongsFollowShopOrder() {
        XCTAssertEqual(viewModel.ownedSongs, [.hotPursuit, .raceDuel, .urbanChase])
    }

    func testNextAndPreviousSongWrapAround() {
        viewModel.nextSong()
        XCTAssertEqual(persistence.selectedSong, .raceDuel)
        viewModel.nextSong()
        viewModel.nextSong()
        XCTAssertEqual(persistence.selectedSong, .hotPursuit)
        viewModel.previousSong()
        XCTAssertEqual(persistence.selectedSong, .urbanChase)
    }

    func testUnownedSelectionJumpsToFirstOwnedSong() {
        persistence.selectedSong = .catchMe
        viewModel.nextSong()
        XCTAssertEqual(persistence.selectedSong, .hotPursuit)
    }

    func testSongDisplayNameComesFromShop() {
        XCTAssertEqual(viewModel.displayName(of: .bornLucky), "Born Lucky")
    }

    // MARK: - Car

    func testBlueCarIsAlwaysOwned() {
        XCTAssertTrue(viewModel.isOwned(.blue))
        XCTAssertFalse(viewModel.isOwned(.red))
    }

    func testSelectsOwnedCar() {
        persistence.unlocked.insert("greencar")
        viewModel.select(.green)
        XCTAssertEqual(persistence.selectedCar, .green)
        XCTAssertEqual(viewModel.selectedCar, .green)
    }

    func testLockedCarCannotBeSelected() {
        viewModel.select(.red)
        XCTAssertEqual(persistence.selectedCar, .blue)
    }
}
