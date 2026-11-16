import XCTest

/// Taps through Dev mode the way a person would: the DEV menu, the Shop, and the
/// in-game DEV panel. Every test starts on a throwaway profile (`-freshProfile`), so
/// nothing touches real saves.
final class DevModeUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-freshProfile"] + arguments
        app.launch()
        return app
    }

    /// The DEV panel readout, e.g. "t 3.1s · … · speed 4× · … · honks 0 · …".
    @MainActor
    private func readout(_ app: XCUIApplication) -> String {
        let element = app.staticTexts["dev.readout"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element.label
    }

    /// Swipes the DEV menu up until `element` is on screen (its form loads rows lazily).
    @MainActor
    private func scroll(to element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element) never came on screen")
    }

    // MARK: - Real profile: money and high score

    /// Opens the DEV menu, whose Real Profile section is at the top.
    @MainActor
    private func openDevMenu(_ app: XCUIApplication) {
        app.buttons["dev.button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dev.bank"].waitForExistence(timeout: 5))
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
    private func shopBank(_ app: XCUIApplication) -> String {
        app.buttons["SHOP"].tap()
        let bank = app.descendants(matching: .any)["shop.bank"]
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        return bank.label
    }

    @MainActor
    func testAddedMoneyShowsInShop() {
        let app = launch()
        openDevMenu(app)
        app.buttons["dev.add10000"].tap()
        app.buttons["dev.add1000"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["dev.bank"].label, "Bank, $11,000")
        app.buttons["Done"].tap()

        XCTAssertEqual(shopBank(app), "Bank: $11,000")
    }

    @MainActor
    func testSetBankThenBuyInShop() {
        let app = launch()
        openDevMenu(app)
        set("dev.setBank", to: "5000", in: app)
        app.buttons["Done"].tap()
        XCTAssertEqual(shopBank(app), "Bank: $5,000")

        app.buttons["Red Rocket, $500"].tap()
        app.buttons["Buy for $500"].tap()
        let bank = app.descendants(matching: .any)["shop.bank"]
        XCTAssertTrue(bank.waitForLabel("Bank: $4,500"), bank.label)
    }

    @MainActor
    func testSetHighScoreShowsAsBestInGame() {
        let app = launch()
        openDevMenu(app)
        set("dev.setHighScore", to: "777", in: app)
        XCTAssertEqual(app.descendants(matching: .any)["dev.highScore"].label, "High score, 777")
        app.buttons["Done"].tap()

        app.buttons["NEW GAME"].tap()
        let best = app.descendants(matching: .any)["hud.best"]
        XCTAssertTrue(best.waitForExistence(timeout: 5))
        XCTAssertTrue(best.label.contains("777"), best.label)
    }

    // MARK: - In-game DEV panel

    @MainActor
    func testTimeScaleBarChangesSpeedWithoutHonking() {
        let app = launch(["-devScenario", "godCruise", "-devOverlay"])
        XCTAssertTrue(readout(app).contains("speed 1×"))

        app.buttons["4×"].tap()
        sleep(1)   // the readout refreshes twice a second
        let text = readout(app)
        XCTAssertTrue(text.contains("speed 4×"), text)
        XCTAssertTrue(text.contains("honks 0"), "a tap on the panel must not honk: \(text)")
    }

    /// The road below the panel still steers and honks.
    @MainActor
    func testOpenRoadStillSteersAndHonks() {
        let app = launch(["-devScenario", "godCruise", "-devOverlay"])
        XCTAssertTrue(readout(app).contains("car 0"))

        let road = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        road.tap()
        sleep(1)
        XCTAssertTrue(readout(app).contains("honks 1"), "a tap on the road honks")

        road.press(forDuration: 0.1, thenDragTo: road.withOffset(CGVector(dx: 120, dy: 0)))
        sleep(1)
        let text = readout(app)
        XCTAssertFalse(text.contains("car 0 "), "dragging right steers the car: \(text)")
    }
}

extension XCUIElement {
    /// Waits up to `timeout` seconds for the element's label to become `label`.
    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
