import XCTest

final class InstallerAcquisitionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func element(_ text: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "value == %@ OR label == %@", text, text))
            .firstMatch
    }

    @MainActor
    func testCatalogFailureExplainsHowToRetry() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers", "-sampleCatalogUnavailable", "YES",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        XCTAssertTrue(window.buttons["Try Again"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.descendants(matching: .any)["Installer List Unavailable"].exists)
        XCTAssertTrue(window.staticTexts["Relente couldn’t load Apple’s installer list. Try again."].exists)
        XCTAssertFalse(window.staticTexts["Choose a full installer available for this Mac."].exists)
    }

    @MainActor
    func testRecoveryOffersFinderWithoutMisleadingEmptyCatalog() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers", "-sampleRecoveryRequired", "YES",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        XCTAssertTrue(window.buttons["Open Folder in Finder"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.staticTexts["No Full Installers Available"].exists)
        XCTAssertTrue(window.staticTexts["Review the pending work before downloading."].exists)
        XCTAssertTrue(
            window.descendants(matching: .any)["Previous Download Needs Review"].exists
        )
        XCTAssertFalse(window.buttons["Continue"].isEnabled)
        XCTAssertTrue(window.buttons["Back"].isEnabled)
    }

    @MainActor
    func testRecoveryPendingDoesNotPreventNormalQuit() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers", "-sampleRecoveryRequired", "YES",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        XCTAssertTrue(window.buttons["Open Folder in Finder"].waitForExistence(timeout: 5))
        window.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    @MainActor
    func testCompletedSampleBecomesSelectableBeforeTheUSBStep() {
        let app = XCUIApplication.relente(extraArguments: ["-sampleEmpty", "installers"])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        let download = window.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        let use = window.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        let ready = NSPredicate(format: "label == %@ AND enabled == true", "Use macOS Tahoe 26.1")
        expectation(for: ready, evaluatedWith: use)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(window.sheets.firstMatch.descendants(matching: .any)["Installer ready"].exists)
        window.sheets.buttons["Close"].click()
        XCTAssertTrue(window.sheets.firstMatch.waitForNonExistence(timeout: 5))
        use.click()
        XCTAssertTrue(window.buttons["Continue"].isEnabled)
        window.buttons["Continue"].click()
        XCTAssertTrue(element("Choose a USB Drive", in: window).waitForExistence(timeout: 5))
        XCTAssertTrue(element("Installer: macOS Tahoe 26.1, 16.8 GB", in: window).exists)
    }

    @MainActor
    func testFailedSampleDownloadExplainsReasonAndOffersRecoveryAction() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers", "-sampleDownloadFailure", "YES",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        let download = window.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        let reason = window.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
                "The installer download was incomplete or had an unexpected size. Try again.",
                "The installer download was incomplete or had an unexpected size. Try again."
            )
        ).firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(window.sheets.buttons["Retry Download"].exists)
    }

    @MainActor
    func testCancellationConfirmationKeepsTheDownloadByDefault() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers",
            "-sampleDownloadDelayMilliseconds", "60000",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        let download = window.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        let cancel = window.sheets.buttons["Cancel Download"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let sheet = window.sheets.firstMatch
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
        XCTAssertFalse(window.buttons["Activity"].exists)
        sheet.buttons["Close"].click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertFalse(window.buttons["Cancel Download"].exists)
        let artwork = window.buttons["installer-artwork-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(artwork.exists)
        artwork.click()
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: window.screenshot())
        screenshot.name = "Download details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        cancel.click()
        let alert = window.sheets["alert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        window.typeKey("\r", modifierFlags: [])
        XCTAssertFalse(alert.exists)
        XCTAssertTrue(cancel.exists)
        cancel.click()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancel Download"].click()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(window.sheets.buttons["Retry Download"].exists)
        XCTAssertTrue(window.sheets.firstMatch.descendants(matching: .any)["Download cancelled"].exists)
        window.sheets.buttons["Close"].click()
        XCTAssertTrue(window.sheets.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Back"].isEnabled)
        XCTAssertTrue(element("Download macOS", in: window).exists)
        XCTAssertFalse(window.buttons["Continue"].isEnabled)
    }
    @MainActor
    func testQuitKeepsWaitingByDefaultAndCanCancelBeforeTerminating() {
        let app = XCUIApplication.relente(extraArguments: [
            "-sampleEmpty", "installers",
            "-sampleDownloadDelayMilliseconds", "60000",
        ])
        let window = app.windows.firstMatch
        XCTAssertTrue(window.buttons["Download from Apple…"].waitForExistence(timeout: 5))
        window.buttons["Download from Apple…"].click()
        let download = window.buttons["installer-action-26.1|25B354|macOS Tahoe"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()
        XCTAssertTrue(window.sheets.buttons["Cancel Download"].waitForExistence(timeout: 5))
        window.typeKey("q", modifierFlags: .command)
        let keepWaiting = window.sheets.buttons["Keep Waiting"]
        XCTAssertTrue(keepWaiting.waitForExistence(timeout: 5))
        keepWaiting.click()
        XCTAssertTrue(keepWaiting.waitForNonExistence(timeout: 5))
        XCTAssertTrue(window.sheets.buttons["Cancel Download"].exists)
        window.typeKey("q", modifierFlags: .command)
        let cancelAndQuit = window.sheets.buttons["Cancel Download and Quit"]
        XCTAssertTrue(cancelAndQuit.waitForExistence(timeout: 5))
        cancelAndQuit.click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

}
