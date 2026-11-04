//
//  CreatingScreenUITests.swift
//  RelenteUITests
//
//  The Creating screen in the running app, reached by navigating, with the Debug-only
//  simulation: Esc presses "Cancel"; in the confirmation Return and Esc keep going and only a
//  click stops; stopping shows Error, whose buttons go to Review or back to the start.
//

import XCTest

final class CreatingScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Opens the app and walks to Creating. The simulation runs at normal speed (about 15 s), so
    /// the screen stays long enough for each test.
    @MainActor
    private func launch(extraArguments: [String] = [], simulationSpeed: String = "normal") {
        app = .relente(simulationSpeed: simulationSpeed, extraArguments: extraArguments)
        app.startCreating()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    }

    /// The confirmation's "Stop" button: it's only there while the sheet is open.
    @MainActor
    private var stopButton: XCUIElement {
        app.sheets.buttons["Stop"]
    }

    /// Cancel, then Stop: the Error screen with reason "Cancelled".
    @MainActor
    private func stop() {
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.click()
        XCTAssertTrue(app.element("Couldn't Create the Installer").waitForExistence(timeout: 5))
    }

    // MARK: - Cancel confirmation

    @MainActor
    func testEscPressesCancel() {
        launch()
        app.press(.escape)
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testReturnInTheConfirmationKeepsGoing() {
        launch()
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        app.press(.return)
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].exists, "Still creating")
    }

    @MainActor
    func testEscInTheConfirmationKeepsGoing() {
        launch()
        app.buttons["Cancel"].click()
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))

        app.press(.escape)
        XCTAssertTrue(stopButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].exists, "Still creating")
    }

    // MARK: - Error

    @MainActor
    func testOnlyAClickStopsAndShowsTheError() {
        launch()
        stop()
        // STOPPED AT reads as one element together with its figure.
        let stoppedAt = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "STOPPED AT", "STOPPED AT"))
            .firstMatch
        XCTAssertTrue(stoppedAt.exists)
        XCTAssertTrue(app.buttons["Try Again"].exists)
        XCTAssertTrue(app.buttons["Start Over"].exists)
    }

    @MainActor
    func testTryAgainGoesToReviewUnconfirmed() {
        launch()
        stop()
        app.buttons["Try Again"].click()
        XCTAssertTrue(app.element("Review and Create").waitForExistence(timeout: 5))
        XCTAssertEqual(app.checkBoxes.firstMatch.value as? Int, 0, "The erase must be confirmed again")
    }

    @MainActor
    func testStartOverGoesToTheInstallerScreen() {
        launch()
        stop()
        app.buttons["Start Over"].click()
        XCTAssertTrue(app.element("Choose an Installer").waitForExistence(timeout: 5))
    }

    @MainActor
    func testASimulatedFailureShowsItsReason() {
        app = .relente(simulationSpeed: "fast", extraArguments: ["-simulateFailure", "driveDisconnected"])
        app.startCreating()
        XCTAssertTrue(app.element("Couldn't Create the Installer").waitForExistence(timeout: 10))
        let reason = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "value BEGINSWITH %@ OR label BEGINSWITH %@", "The drive was disconnected.",
                    "The drive was disconnected.")
            )
            .firstMatch
        XCTAssertTrue(reason.exists)
    }

    @MainActor
    func testDiskAccessFailureOffersSettings() {
        app = .relente(simulationSpeed: "fast", extraArguments: ["-simulateFailure", "volumeAccessDenied"])
        app.startCreating()
        XCTAssertTrue(app.element("Couldn't Create the Installer").waitForExistence(timeout: 10))
        XCTAssertTrue(app.links["Open Full Disk Access Settings…"].exists)
    }

    // MARK: - Simulation label

    @MainActor
    func testTheSimulationIsLabelledWhileCreatingAndOnError() {
        launch()
        XCTAssertTrue(app.element("SIMULATION · Nothing is erased").exists)
        stop()
        XCTAssertTrue(app.element("SIMULATION · Nothing is erased").exists)
    }

    @MainActor
    func testCreationPhasesAreVisibleWithoutActivity() {
        launch()
        XCTAssertFalse(app.buttons["Activity"].exists)
        for phase in ["format", "copy", "makeBootable", "verify"] {
            XCTAssertTrue(app.descendants(matching: .any)["creation.phase.\(phase)"].exists)
        }
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    @MainActor
    func testFailureRemainsVisibleWithoutActivity() {
        launch(simulationSpeed: "slow")
        stop()
        XCTAssertFalse(app.buttons["Activity"].exists)
        XCTAssertTrue(app.buttons["Start Over"].exists)
    }

    @MainActor
    func testLiveCopyShowsIndeterminateFeedbackWithoutActivity() {
        app = .relente(simulationSpeed: "slow", extraArguments: ["-simulateLiveFeedback", "YES"])
        app.startCreating()
        XCTAssertTrue(app.staticTexts["Erasing and formatting the USB drive…"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.debugDescription.contains("COPIED"))

        let elapsed = app.descendants(matching: .any)["creation.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Copying installer files to the USB drive…"].waitForExistence(timeout: 10))
        let copied = app.descendants(matching: .any)["creation.copied"]
        XCTAssertTrue(copied.exists)
        let copiedValue = copied.value as? String ?? ""
        XCTAssertTrue(copiedValue.contains("Waiting…"))
        XCTAssertTrue(copiedValue.contains("Waiting for installer image data…"))
        XCTAssertFalse(app.descendants(matching: .any)["creation.remaining"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["creation.indeterminateProgress"].exists)
        XCTAssertFalse(app.buttons["Activity"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    @MainActor
    func testMeasuredLiveCopyShowsBytesAndProgressWithoutSpinner() {
        app = .relente(
            simulationSpeed: "slow",
            extraArguments: ["-simulateLiveFeedback", "YES", "-simulateMeasuredCopy", "YES"])
        app.startCreating()
        XCTAssertTrue(app.staticTexts["Copying installer files to the USB drive…"].waitForExistence(timeout: 10))

        let copied = app.descendants(matching: .any)["creation.copied"]
        let measuredCaption = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "of 16.8 GB"), object: copied)
        XCTAssertEqual(XCTWaiter.wait(for: [measuredCaption], timeout: 8), .completed)
        let copiedValue = copied.value as? String ?? ""
        XCTAssertFalse(copiedValue.contains("Waiting…"), "Measured bytes should replace the waiting state")
        XCTAssertFalse(copiedValue.contains("—"), "Measured copy must not use an empty placeholder")
        XCTAssertFalse(app.descendants(matching: .any)["creation.indeterminateProgress"].exists)

    }
}
