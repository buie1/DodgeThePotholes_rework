import XCTest

/// The in-game DEV panel: every control works, and none of them honks or steers.
final class DevPanelUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// A god-mode run with the DEV panel open.
    @MainActor
    private func launchRun() -> XCUIApplication {
        let app = launchApp(["-devScenario", "godCruise", "-devOverlay"])
        XCTAssertTrue(waitForReadout("speed 1×", in: app, timeout: 10))
        return app
    }

    @MainActor
    func testTimeScaleBarChangesSpeedWithoutHonking() {
        let app = launchRun()
        app.buttons["4×"].tap()
        XCTAssertTrue(waitForReadout("speed 4×", in: app), readout(app))
        app.buttons["0.5×"].tap()
        XCTAssertTrue(waitForReadout("speed 0.5×", in: app), readout(app))
        XCTAssertTrue(readout(app).contains("honks 0"), "a tap on the panel must not honk")
    }

    @MainActor
    func testPauseStepAndSpeedJump() {
        let app = launchRun()
        app.buttons["+30 s"].tap()
        XCTAssertTrue(waitForReadout("travel 1.70s", in: app), readout(app))

        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
        let paused = readout(app)
        sleep(1)
        XCTAssertEqual(readout(app).prefix(8), paused.prefix(8), "time stands still while paused")
        app.buttons["Step"].tap()
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))
        XCTAssertTrue(readout(app).contains("honks 0"))
    }

    @MainActor
    func testChipsShowTheScenarioAndToggleIt() {
        let app = launchRun()
        // godCruise starts in god mode; the panel must show it once play begins.
        XCTAssertEqual(app.buttons["God"].value as? String, "on")
        XCTAssertEqual(app.buttons["Autopilot"].value as? String, "off")

        app.buttons["God"].tap()
        XCTAssertEqual(app.buttons["God"].value as? String, "off")
        app.buttons["God"].tap()
        XCTAssertEqual(app.buttons["God"].value as? String, "on")
    }

    @MainActor
    func testTogglesAndSpawnMenusDontHonk() {
        let app = launchRun()
        for chip in ["Hitboxes", "Autopilot", "Autopilot"] {
            app.buttons[chip].tap()
        }
        for (menu, item) in [("Obstacle ▾", "ambulance"), ("Pickup ▾", "wrap"), ("Activate ▾", "x2")] {
            tapWhenReady(app.buttons[menu])
            tapWhenReady(app.buttons[item])
        }
        XCTAssertTrue(waitForReadout("honks 0", in: app), readout(app))
        XCTAssertFalse(app.buttons["PLAY AGAIN"].exists, "god mode kept the run alive")
    }

    /// The road below the panel still steers and honks.
    @MainActor
    func testOpenRoadStillSteersAndHonks() {
        let app = launchRun()
        XCTAssertTrue(readout(app).contains("car 0 "))

        let road = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        road.tap()
        XCTAssertTrue(waitForReadout("honks 1", in: app), "a tap on the road honks")

        road.press(forDuration: 0.1, thenDragTo: road.withOffset(CGVector(dx: 120, dy: 0)))
        sleep(1)
        XCTAssertFalse(readout(app).contains("car 0 "), "dragging right steers the car: \(readout(app))")
    }
}
