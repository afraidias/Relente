//
//  CreatingScreenUITests.swift
//  RelenteUITests
//
//  Cancelling on the Creating screen, in the running app: Esc presses "Cancel", and in the
//  confirmation Return and Esc keep going; only a click stops. The app is opened on Creating with
//  the Debug-only `-startScreen creating` argument until navigation exists (roadmap step 4).
//  Specs: specs/004-creating-screen/spec.md, specs/005-done-screen/spec.md
//

import XCTest

final class CreatingScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Opens the app on Creating, in English whatever the language of the Mac running the tests.
    @MainActor
    private func launch() {
        app = XCUIApplication()
        // A fresh window each time: ignore the windows macOS saved from the last run.
        app.launchArguments = [
            "-startScreen", "creating", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    }

    /// The confirmation's "Stop" button: it's only there while the sheet is open.
    @MainActor
    private var stopButton: XCUIElement {
        app.sheets.buttons["Stop"]
    }

    @MainActor
    func testEscPressesCancel() {
        launch()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testReturnInTheConfirmationKeepsGoing() {
        launch()
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].exists, "Still creating")
    }

    @MainActor
    func testEscInTheConfirmationKeepsGoing() {
        launch()
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].exists, "Still creating")
    }

    @MainActor
    func testOnlyAClickStops() {
        launch()
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        stopButton.click()
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5))
    }
}
