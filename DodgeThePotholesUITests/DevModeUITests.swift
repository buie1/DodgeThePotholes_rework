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

    // MARK: - Money for the Shop

    @MainActor
    func testAddedMoneyShowsInShop() {
        let app = launch()
        app.buttons["dev.button"].tap()
        let addMoney = app.buttons["Add $10,000"].firstMatch
        scroll(to: addMoney, in: app)
        addMoney.tap()
        app.sheets.buttons["Add $10,000"].firstMatch.tap()
        app.buttons["Done"].tap()

        app.buttons["SHOP"].tap()
        let bank = app.descendants(matching: .any)["shop.bank"]
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        XCTAssertEqual(bank.label, "Bank: $10,000")
    }

    // MARK: - In-game DEV panel

    @MainActor
    func testTimeScaleBarChangesSpeedWithoutHonking() {
        XCTExpectFailure("Bug F2: the steering gesture takes taps meant for the DEV panel")
        let app = launch(["-devScenario", "godCruise", "-devOverlay"])
        XCTAssertTrue(readout(app).contains("speed 1×"))

        app.buttons["4×"].tap()
        sleep(1)   // the readout refreshes twice a second
        let text = readout(app)
        XCTAssertTrue(text.contains("speed 4×"), text)
        XCTAssertTrue(text.contains("honks 0"), "a tap on the panel must not honk: \(text)")
    }
}
