import XCTest
@testable import DodgeThePotholes

/// Saved progress: legacy migration, shop purchases, extra life and banking run earnings.
@MainActor
final class PersistenceServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "PersistenceServiceTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeService() -> SwiftDataPersistenceService {
        SwiftDataPersistenceService.inMemory(defaults: defaults)
    }

    private func item(_ id: String) -> ShopItem {
        ShopItem.allItems.first { $0.id == id }!
    }

    // MARK: - Fresh install

    func testFreshInstallDefaults() {
        let store = makeService()
        XCTAssertEqual(store.money, 0)
        XCTAssertEqual(store.highScore, 0)
        XCTAssertEqual(store.selectedCar, .blue)
        XCTAssertEqual(store.selectedSong, .hotPursuit)
        XCTAssertTrue(store.isSFXEnabled)
        XCTAssertTrue(store.isMusicEnabled)
        XCTAssertTrue(store.isUnlocked(CarSkin.blue))
        XCTAssertFalse(store.isUnlocked(CarSkin.red))
        XCTAssertTrue(store.isUnlocked(GameSound.hotPursuit.rawValue))
        XCTAssertFalse(store.isUnlocked(GameSound.raceDuel.rawValue))
        XCTAssertFalse(store.hasTank)
        XCTAssertTrue(defaults.bool(forKey: SwiftDataPersistenceService.migrationFlagKey))
    }

    // MARK: - Legacy migration

    func testMigratesLegacyDefaults() {
        defaults.set(1_234, forKey: "money")
        defaults.set(9_876, forKey: "highscore")
        defaults.set("car3", forKey: "car")
        defaults.set(false, forKey: "sfx")
        defaults.set(false, forKey: "music")
        defaults.set("race_duel.wav", forKey: "song_selected")
        defaults.set(false, forKey: "redcar")
        defaults.set(true, forKey: "greencar")
        defaults.set(true, forKey: "tank")
        defaults.set(true, forKey: "life")
        defaults.set(["hot-pursuit.wav": true, "race_duel.wav": true, "catch_me.wav": false],
                     forKey: "songs")

        let store = makeService()

        XCTAssertEqual(store.money, 1_234)
        XCTAssertEqual(store.highScore, 9_876)
        XCTAssertEqual(store.selectedCar, .green)
        XCTAssertEqual(store.selectedSong, .raceDuel)
        XCTAssertFalse(store.isSFXEnabled)
        XCTAssertFalse(store.isMusicEnabled)
        XCTAssertFalse(store.isUnlocked(CarSkin.red))
        XCTAssertTrue(store.isUnlocked(CarSkin.green))
        XCTAssertTrue(store.hasTank)
        XCTAssertTrue(store.extraLifePending)
        XCTAssertTrue(store.isUnlocked("race_duel.wav"))
        XCTAssertFalse(store.isUnlocked("catch_me.wav"))
    }

    func testMigrationRunsOnlyOnce() {
        defaults.set(true, forKey: SwiftDataPersistenceService.migrationFlagKey)
        defaults.set(5_000, forKey: "money")
        XCTAssertEqual(makeService().money, 0)
    }

    func testUnknownLegacyCarFallsBackToBlue() {
        defaults.set("tank", forKey: "car")
        XCTAssertEqual(makeService().selectedCar, .blue)
    }

    // MARK: - Shop

    func testPurchaseNeedsEnoughMoney() {
        let store = makeService()
        XCTAssertEqual(store.purchase(item("redcar")), .insufficientFunds)
        XCTAssertFalse(store.isUnlocked(CarSkin.red))
        XCTAssertEqual(store.money, 0)
    }

    func testPurchaseSpendsMoneyAndUnlocks() {
        let store = makeService()
        store.recordRun(score: 10, moneyEarned: 700)

        XCTAssertEqual(store.purchase(item("redcar")), .purchased)
        XCTAssertEqual(store.money, 700 - GameConfig.ShopCost.car)
        XCTAssertTrue(store.isUnlocked(CarSkin.red))
        XCTAssertEqual(store.purchase(item("redcar")), .alreadyOwned)
        XCTAssertEqual(store.money, 700 - GameConfig.ShopCost.car)
    }

    func testFreeSongIsAlreadyOwned() {
        let store = makeService()
        store.recordRun(score: 10, moneyEarned: 1_000)
        XCTAssertEqual(store.purchase(item("hot-pursuit.wav")), .alreadyOwned)
        XCTAssertEqual(store.money, 1_000)
    }

    func testTankPurchaseSetsHasTank() {
        let store = makeService()
        store.recordRun(score: 10, moneyEarned: GameConfig.ShopCost.tank)
        XCTAssertEqual(store.purchase(item("tank")), .purchased)
        XCTAssertTrue(store.hasTank)
    }

    // MARK: - Extra life

    func testExtraLifeIsSpentByOneRunAndCanBeRebought() {
        let store = makeService()
        store.recordRun(score: 10, moneyEarned: 2 * GameConfig.ShopCost.life)

        XCTAssertEqual(store.purchase(item("life")), .purchased)
        XCTAssertEqual(store.purchase(item("life")), .alreadyOwned)
        XCTAssertTrue(store.consumeExtraLife())
        XCTAssertFalse(store.consumeExtraLife())
        XCTAssertEqual(store.purchase(item("life")), .purchased)
        XCTAssertEqual(store.money, 0)
    }

    // MARK: - Runs

    func testRecordRunBanksMoneyAndTracksHighScore() {
        let store = makeService()
        XCTAssertTrue(store.recordRun(score: 500, moneyEarned: 40))
        XCTAssertFalse(store.recordRun(score: 300, moneyEarned: 60))
        XCTAssertEqual(store.money, 100)
        XCTAssertEqual(store.highScore, 500)
    }

    func testBestRunsAreSortedAndLimited() {
        let store = makeService()
        for score in [300, 900, 100, 700, 500] {
            store.recordRun(score: score, moneyEarned: score / 100)
        }

        let best = store.bestRuns(limit: 3)
        XCTAssertEqual(best.map(\.score), [900, 700, 500])
        XCTAssertEqual(best.first?.moneyEarned, 9)
        XCTAssertEqual(store.bestRuns(limit: 10).count, 5)
    }

    // MARK: - Preferences

    func testPreferencesPersistAcrossInstances() throws {
        let container = try SwiftDataPersistenceService.makeContainer(inMemory: true)
        let first = SwiftDataPersistenceService(container: container, defaults: defaults)
        first.selectedSong = .catchMe
        first.isMusicEnabled = false
        first.recordRun(score: 42, moneyEarned: 7)

        let second = SwiftDataPersistenceService(container: container, defaults: defaults)
        XCTAssertEqual(second.selectedSong, .catchMe)
        XCTAssertFalse(second.isMusicEnabled)
        XCTAssertEqual(second.money, 7)
        XCTAssertEqual(second.highScore, 42)
    }
}
