import XCTest

/// The main menu, the Shop and Settings, tapped through on a fresh profile.
final class MenuAndShopUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Navigation

    @MainActor
    func testEveryMenuScreenOpensAndReturns() {
        let app = launchApp()

        app.buttons["LEADERBOARD"].tap()
        XCTAssertTrue(app.staticTexts["YOUR BEST"].waitForExistence(timeout: 5))
        goBack(app)

        _ = openShop(app)
        goBack(app)

        app.buttons["SETTINGS"].tap()
        app.buttons["AUDIO"].tap()
        XCTAssertTrue(app.switches["MUSIC"].waitForExistence(timeout: 5))
        goBack(app)
        app.buttons["CAR"].tap()
        XCTAssertTrue(app.staticTexts["BUY LOCKED CARS IN THE SHOP"].waitForExistence(timeout: 5))
        goBack(app)
        goBack(app)

        XCTAssertTrue(app.buttons["NEW GAME"].waitForExistence(timeout: 5))
    }

    // MARK: - Shop

    @MainActor
    func testNotEnoughMoneyShowsAnAlert() {
        let app = launchApp()
        _ = openShop(app)
        app.buttons["Red Rocket, $500"].tap()
        XCTAssertTrue(app.alerts["Insufficient Funds"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
    }

    @MainActor
    func testBuyingTwiceSaysAlreadyPurchased() {
        let app = launchApp(bank: 1_000)
        let bank = openShop(app)
        app.buttons["Red Rocket, $500"].tap()
        app.buttons["Buy for $500"].tap()
        XCTAssertTrue(bank.waitForLabel("Bank: $500"))

        app.buttons["Red Rocket, owned"].tap()
        XCTAssertTrue(app.alerts["Already Purchased"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertEqual(bank.label, "Bank: $500", "no second charge")
    }

    @MainActor
    func testExtraLifeIsUsedOnTheNextRun() {
        let app = launchApp(bank: 1_000)
        _ = openShop(app)
        app.buttons["Extra Life, $1000"].tap()
        app.buttons["Buy for $1,000"].tap()   // the dialog groups thousands; the row label doesn't
        XCTAssertTrue(app.buttons["Extra Life, ready"].waitForExistence(timeout: 5))
        goBack(app)

        app.buttons["NEW GAME"].tap()
        XCTAssertTrue(element("4 lives", in: app).waitForExistence(timeout: 5), "3 lives + the bought one")
    }

    // MARK: - Settings

    @MainActor
    func testOnlyOwnedCarsCanBeSelected() {
        let app = launchApp(bank: 500)
        app.buttons["SETTINGS"].tap()
        app.buttons["CAR"].tap()
        app.buttons["Red Rocket, locked"].tap()
        XCTAssertTrue(app.buttons["Blue Racer, selected"].exists, "a locked car can't be picked")
        goBack(app)
        goBack(app)

        _ = openShop(app)
        app.buttons["Red Rocket, $500"].tap()
        app.buttons["Buy for $500"].tap()
        goBack(app)

        app.buttons["SETTINGS"].tap()
        app.buttons["CAR"].tap()
        app.buttons["Red Rocket, owned"].tap()
        XCTAssertTrue(app.buttons["Red Rocket, selected"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAudioSettingsStick() {
        let app = launchApp()
        app.buttons["SETTINGS"].tap()
        app.buttons["AUDIO"].tap()
        let music = app.switches["MUSIC"]
        XCTAssertTrue(music.waitForExistence(timeout: 5))
        let before = music.value as? String
        // Tap the switch itself (right edge); the middle of the row is its label.
        music.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertNotEqual(music.value as? String, before)

        goBack(app)
        app.buttons["AUDIO"].tap()
        XCTAssertNotEqual(app.switches["MUSIC"].value as? String, before, "the change was saved")
    }
}
