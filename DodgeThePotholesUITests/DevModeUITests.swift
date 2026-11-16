import XCTest

/// The DEV menu's real-profile tools and presets, as a person would use them.
final class DevModeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Types `value` into a DEV menu number field and taps its Set button.
    @MainActor
    private func set(_ id: String, to value: String, in app: XCUIApplication) {
        let field = app.textFields["\(id)Field"]
        field.tap()
        field.typeText(value)
        app.buttons[id].tap()
    }

    @MainActor
    func testAddedMoneyShowsInShop() {
        let app = launchApp()
        openDevMenu(app)
        app.buttons["dev.add10000"].tap()
        app.buttons["dev.add1000"].tap()
        XCTAssertEqual(element("dev.bank", in: app).label, "Bank, $11,000")
        app.buttons["Done"].tap()

        XCTAssertEqual(openShop(app).label, "Bank: $11,000")
    }

    @MainActor
    func testSetBankThenBuyInShop() {
        let app = launchApp()
        openDevMenu(app)
        set("dev.setBank", to: "5000", in: app)
        app.buttons["Done"].tap()
        let bank = openShop(app)
        XCTAssertEqual(bank.label, "Bank: $5,000")

        app.buttons["Red Rocket, $500"].tap()
        app.buttons["Buy for $500"].tap()
        XCTAssertTrue(bank.waitForLabel("Bank: $4,500"), bank.label)
    }

    @MainActor
    func testSetHighScoreShowsAsBestInGame() {
        let app = launchApp()
        openDevMenu(app)
        set("dev.setHighScore", to: "777", in: app)
        XCTAssertEqual(element("dev.highScore", in: app).label, "High score, 777")
        app.buttons["Done"].tap()

        app.buttons["NEW GAME"].tap()
        let best = element("hud.best", in: app)
        XCTAssertTrue(best.waitForExistence(timeout: 5))
        XCTAssertTrue(best.label.contains("777"), best.label)
    }

    @MainActor
    func testUnlockEverythingThenResetProgress() {
        let app = launchApp(bank: 300)
        openDevMenu(app)
        app.buttons["dev.unlockAll"].tap()
        app.sheets.buttons["Unlock everything"].tap()
        app.buttons["Done"].tap()
        _ = openShop(app)
        XCTAssertTrue(app.buttons["Red Rocket, owned"].exists)
        goBack(app)

        openDevMenu(app)
        app.buttons["dev.resetProgress"].tap()
        app.sheets.buttons["Reset progress"].tap()
        XCTAssertEqual(element("dev.bank", in: app).label, "Bank, $0")
        app.buttons["Done"].tap()
        _ = openShop(app)
        XCTAssertTrue(app.buttons["Red Rocket, $500"].exists, "reset takes the unlocks back")
    }

    @MainActor
    func testPresetStartsADevRun() {
        let app = launchApp()
        app.buttons["dev.button"].tap()
        // A form picker's label includes its value, e.g. "Preset, None".
        tapWhenReady(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Preset")).firstMatch)
        tapWhenReady(app.buttons["lateGame"])
        let start = app.buttons["Start Run"]
        scroll(to: start, in: app)
        start.tap()

        // lateGame starts near top speed (travel 0.30 s instead of 2.00 s).
        // The main menu's DEV button stays in the tree behind the run; the run's comes first.
        let inGameDev = app.buttons.matching(identifier: "dev.button").firstMatch
        tapWhenReady(inGameDev)
        XCTAssertTrue(waitForReadout("travel 0.30s", in: app), readout(app))
    }
}
