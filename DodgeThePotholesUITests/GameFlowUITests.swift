import XCTest

/// A whole run: start, game over, Play Again, back to the menu.
final class GameFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// One life on a road of potholes ends a run within a few seconds.
    private static let quickDeath = #"{"seed": 42, "lives": 1, "obstacles": [{"spawn": "pothole", "weight": 1}]}"#

    @MainActor
    func testGameOverPlayAgainAndMainMenu() {
        let app = launchApp(["-devScenarioJSON", Self.quickDeath])

        let playAgain = app.buttons["PLAY AGAIN"]
        XCTAssertTrue(playAgain.waitForExistence(timeout: 30), "the run ends")
        XCTAssertTrue(app.staticTexts["NEAR MISSES"].exists, "the game-over stats show")
        playAgain.tap()
        XCTAssertTrue(playAgain.waitForNonExistence(timeout: 5), "Play Again starts a new run")

        XCTAssertTrue(playAgain.waitForExistence(timeout: 30), "the second run ends too")
        app.buttons["MAIN MENU"].tap()
        XCTAssertTrue(app.buttons["NEW GAME"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewGameStartsARun() {
        let app = launchApp()
        app.buttons["NEW GAME"].tap()
        let best = element("hud.best", in: app)
        XCTAssertTrue(best.waitForExistence(timeout: 5), "the HUD is up")
        XCTAssertTrue(app.buttons["dev.button"].exists, "the in-game DEV button is there")
    }
}
