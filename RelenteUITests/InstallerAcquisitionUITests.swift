import XCTest

final class InstallerAcquisitionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCompletedSampleBecomesSelectableBeforeTheUSBStep() {
        let app = XCUIApplication.relente(extraArguments: ["-sampleEmpty", "installers"])
        XCTAssertTrue(app.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        app.buttons["Download from Apple…"].click()
        let download = app.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        let use = app.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        let ready = NSPredicate(format: "label == %@ AND enabled == true", "Use macOS Tahoe 26.1")
        expectation(for: ready, evaluatedWith: use)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.sheets.firstMatch.descendants(matching: .any)["Installer ready"].exists)
        app.sheets.buttons["Close"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 5))
        use.click()
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].click()
        XCTAssertTrue(app.element("Choose a USB Drive").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("Installer: macOS Tahoe 26.1, 16.8 GB").exists)
    }

    @MainActor
    func testCancellationConfirmationKeepsTheDownloadByDefault() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers",
            "-sampleDownloadDelayMilliseconds", "60000",
        ])
        XCTAssertTrue(app.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        app.buttons["Download from Apple…"].click()
        let download = app.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        let cancel = app.sheets.buttons["Cancel Download"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let sheet = app.sheets.firstMatch
        func stage(_ label: String) -> XCUIElement {
            sheet.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        XCTAssertEqual(stage("Connecting to Apple…").value as? String, "Completed")
        XCTAssertEqual(stage("Downloading from Apple…").value as? String, "In progress")
        XCTAssertEqual(stage("Verifying Apple’s package…").value as? String, "Pending")
        let progress = sheet.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Download progress", "4.2 GB")
        ).firstMatch
        XCTAssertTrue(progress.exists)
        XCTAssertFalse(app.buttons["Activity"].exists)
        sheet.buttons["Close"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Cancel Download"].exists)
        let artwork = app.buttons["installer-artwork-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(artwork.exists)
        artwork.click()
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Download details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        cancel.click()
        let alert = app.sheets["alert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        app.press(.return)
        XCTAssertFalse(alert.exists)
        XCTAssertTrue(cancel.exists)
        cancel.click()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancel Download"].click()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.sheets.buttons["Retry Download"].exists)
        XCTAssertTrue(app.sheets.firstMatch.descendants(matching: .any)["Download cancelled"].exists)
        app.sheets.buttons["Close"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].isEnabled)
        XCTAssertTrue(app.element("Download macOS").exists)
        XCTAssertFalse(app.buttons["Continue"].isEnabled)
    }
    @MainActor
    func testQuitKeepsWaitingByDefaultAndCanCancelBeforeTerminating() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers",
            "-sampleDownloadDelayMilliseconds", "60000",
        ])
        XCTAssertTrue(app.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        app.buttons["Download from Apple…"].click()
        let download = app.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        XCTAssertTrue(app.sheets.buttons["Cancel Download"].waitForExistence(timeout: 5))
        app.menuBars.menuBarItems["Relente"].click()
        app.menuBars.menuItems["Quit Relente"].click()
        let keepWaiting = app.buttons["Keep Waiting"]
        XCTAssertTrue(keepWaiting.waitForExistence(timeout: 5))
        app.press(.return)
        XCTAssertTrue(keepWaiting.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.sheets.buttons["Cancel Download"].exists)
        app.menuBars.menuBarItems["Relente"].click()
        app.menuBars.menuItems["Quit Relente"].click()
        let cancelAndQuit = app.dialogs.buttons["Cancel Download and Quit"]
        XCTAssertTrue(cancelAndQuit.waitForExistence(timeout: 5))
        cancelAndQuit.click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

}
