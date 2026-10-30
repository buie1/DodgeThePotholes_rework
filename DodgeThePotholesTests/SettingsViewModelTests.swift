import XCTest
@testable import DodgeThePotholes

/// Sound switches save through persistence; the song picker cycles owned songs only.
@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var persistence: MockPersistenceService!
    private var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        persistence = MockPersistenceService()
        persistence.unlocked = [GameSound.hotPursuit.rawValue, GameSound.raceDuel.rawValue,
                                GameSound.urbanChase.rawValue]
        viewModel = SettingsViewModel(persistence: persistence)
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
}
