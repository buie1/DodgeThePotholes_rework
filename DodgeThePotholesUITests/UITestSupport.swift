import XCTest

/// Shared steps for the UI tests. Every launch uses `-freshProfile`: an empty throwaway
/// profile, so tests never touch real saves.
extension XCTestCase {

    /// Launches the app on a fresh profile, plus any extra launch arguments.
    /// - Parameter bank: Money on the fresh profile (`-devBank`).
    @MainActor
    func launchApp(_ arguments: [String] = [], bank: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-freshProfile"] + (bank.map { ["-devBank", String($0)] } ?? []) + arguments
        app.launch()
        return app
    }

    /// Any element by accessibility identifier, whatever its type.
    @MainActor
    func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// The DEV panel readout, e.g. "t 3.1s · … · speed 4× · … · car 0 · honks 0 · …".
    @MainActor
    func readout(_ app: XCUIApplication) -> String {
        let readout = app.staticTexts["dev.readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10))
        return readout.label
    }

    /// Waits for the DEV panel readout to contain `text` (it refreshes twice a second).
    @MainActor
    func waitForReadout(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let readout = app.staticTexts["dev.readout"]
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: readout)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits for `target` (e.g. a menu item still animating in or out), then taps it.
    @MainActor
    func tapWhenReady(_ target: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "\(target) never appeared")
        target.tap()
    }

    /// Taps the navigation bar's back button.
    @MainActor
    func goBack(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Opens the DEV menu from the main menu; its Real Profile section is at the top.
    @MainActor
    func openDevMenu(_ app: XCUIApplication) {
        app.buttons["dev.button"].tap()
        XCTAssertTrue(element("dev.bank", in: app).waitForExistence(timeout: 5))
    }

    /// Swipes up until `target` is on screen (forms and lists load rows lazily).
    @MainActor
    func scroll(to target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !target.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable, "\(target) never came on screen")
    }

    /// Opens the Shop from the main menu and returns its bank element.
    @MainActor
    func openShop(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["SHOP"].tap()
        let bank = element("shop.bank", in: app)
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        return bank
    }
}

extension XCUIElement {
    /// Waits up to `timeout` seconds for the element's label to become `label`.
    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
