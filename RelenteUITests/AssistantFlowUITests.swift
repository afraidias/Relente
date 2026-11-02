//
//  AssistantFlowUITests.swift
//  RelenteUITests
//
//  The whole assistant in the running app, with sample data and the Debug-only simulation.
//  Specs: specs/006-assistant-navigation/spec.md, specs/007-real-detection/spec.md,
//  specs/008-system-helper/spec.md, specs/011-installer-acquisition/spec.md
//

import XCTest

final class AssistantFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func expectScreen(
        _ title: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            app.element(title).waitForExistence(timeout: timeout), "Expected “\(title)”", file: file, line: line)
    }

    /// Go › Back (⌘[). Chosen from the menu: the key for ⌘[ depends on the keyboard layout.
    @MainActor
    private func chooseGoBack() {
        let go = app.menuBars.menuBarItems["Go"]
        go.click()
        go.menuItems["Back"].click()
    }

    // MARK: - Tests

    @MainActor
    func testTheWholeFlow() {
        app = .relente(simulationSpeed: "fast")
        app.goToDone()

        app.press(.return)
        expectScreen("Choose an Installer")
    }

    @MainActor
    func testTheWholeFlowWithClassicControls() {
        app = .relente(simulationSpeed: "fast", extraArguments: ["-classicControls", "YES"])
        app.goToDone()

        app.press(.return)
        expectScreen("Choose an Installer")
    }

    @MainActor
    func testPermissionsThenTheWholeFlow() {
        app = .relente(extraArguments: ["-sampleHelper", "notInstalled"])
        expectScreen("Set Up Relente")
        XCTAssertTrue(app.element("The system helper isn't installed.").exists)
        XCTAssertTrue(app.buttons["Install Helper"].exists)
        XCTAssertTrue(app.element("macOS protects access to disks and removable drives.").exists)

        app.buttons["Install Helper"].click()
        XCTAssertTrue(app.element("System helper ready.").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].click()
        expectScreen("Choose an Installer")

        app.goToDone()
        expectScreen("Installer Ready")
    }

    @MainActor
    func testEscAndGoBackMenuGoBack() {
        app = .relente()
        expectScreen("Choose an Installer")

        app.press(.return)
        expectScreen("Choose a USB Drive")
        app.press(.escape)
        expectScreen("Choose an Installer")

        app.press(.return)
        expectScreen("Choose a USB Drive")
        chooseGoBack()
        expectScreen("Choose an Installer")

        app.goToReview()
        app.press(.escape)
        expectScreen("Choose a USB Drive")

        app.press(.return)
        expectScreen("Review and Create")
        chooseGoBack()
        expectScreen("Choose a USB Drive")
    }

    @MainActor
    func testReturnOnReviewDoesNotErase() {
        app = .relente()
        app.goToReview()

        app.confirmErasure()
        app.press(.return)
        XCTAssertFalse(app.element("Creating Installer").waitForExistence(timeout: 2))
        XCTAssertTrue(app.element("Review and Create").exists)
    }

    @MainActor
    func testTheInstallerLabelReadsAsOneElement() {
        app = .relente()
        app.press(.return)
        expectScreen("Choose a USB Drive")
        XCTAssertTrue(app.element("Installer: macOS Tahoe 26.0, 16.8 GB").exists)
    }

    // MARK: - Empty states

    @MainActor
    func testWithNoInstallersTheEmptyStateWaitsAndContinueIsDisabled() {
        app = .relente(extraArguments: ["-sampleEmpty", "installers"])
        expectScreen("Choose an Installer")
        expectScreen("No Installers Found")
        XCTAssertTrue(app.element("Waiting for an installer…").exists)
        XCTAssertTrue(app.buttons["Add Installer…"].exists)
        XCTAssertTrue(app.buttons["Download from Apple…"].exists)
        XCTAssertFalse(app.buttons["Continue"].isEnabled)

        app.press(.return)
        XCTAssertTrue(app.element("Choose an Installer").exists, "Return must not leave the screen")
    }

    @MainActor
    func testDownloadFromEmptyInstallerAndUseTheCompletedSample() {
        app = .relente(simulationSpeed: "fast", extraArguments: ["-sampleEmpty", "installers"])
        expectScreen("Choose an Installer")

        app.buttons["Download from Apple…"].click()
        expectScreen("Download macOS")
        XCTAssertTrue(app.buttons["Download macOS Tahoe 26.1"].exists)
        let olderVersions = app.buttons["Other Tahoe versions"]
        XCTAssertTrue(olderVersions.waitForExistence(timeout: 5))
        olderVersions.click()
        XCTAssertTrue(app.staticTexts["Older Tahoe versions"].waitForExistence(timeout: 5))
        let olderDownload = app.buttons["Download macOS Tahoe 26.0"]
        XCTAssertTrue(olderDownload.waitForExistence(timeout: 5))
        olderDownload.click()
        XCTAssertTrue(app.staticTexts["Older Tahoe versions"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].click()
        XCTAssertTrue(app.buttons["Back"].exists)

        app.buttons["Back"].click()
        expectScreen("Choose an Installer")
        app.buttons["Download from Apple…"].click()
        expectScreen("Download macOS")

        let useButton = app.buttons["Use macOS Tahoe 26.0"]
        XCTAssertTrue(useButton.waitForExistence(timeout: 5))
        useButton.click()
        expectScreen("Choose an Installer")
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].click()
        expectScreen("Choose a USB Drive")
        XCTAssertTrue(app.element("Installer: macOS Tahoe 26.0, 16.8 GB").exists)
    }

    @MainActor
    func testCancellingADownloadRequiresConfirmationAndDefaultsToKeepingIt() {
        app = .relente(
            extraArguments: ["-sampleEmpty", "installers", "-sampleDownloadDelayMilliseconds", "10000"])
        expectScreen("Choose an Installer")
        app.buttons["Download from Apple…"].click()
        expectScreen("Download macOS")

        app.buttons["Download macOS Tahoe 26.1"].click()
        let cancelButton = app.buttons["Cancel Download"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.click()

        let alert = app.alerts["Cancel this download?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Keep Downloading"].exists)
        XCTAssertTrue(alert.buttons["Cancel Download"].exists)
        alert.buttons["Keep Downloading"].click()
        XCTAssertFalse(alert.exists)
        XCTAssertTrue(cancelButton.exists)

        cancelButton.click()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancel Download"].click()
        XCTAssertFalse(cancelButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists, "Cancelling must leave the user on Download")
    }

    @MainActor
    func testWithNoDrivesTheEmptyStateWaitsAndContinueIsDisabled() {
        app = .relente(extraArguments: ["-sampleEmpty", "drives"])
        expectScreen("Choose an Installer")
        app.press(.return)
        expectScreen("Choose a USB Drive")
        expectScreen("No USB Drive Connected")
        XCTAssertTrue(app.element("Waiting for a drive…").exists)
        XCTAssertTrue(app.element("Installer: macOS Tahoe 26.0, 16.8 GB").exists)
        XCTAssertFalse(app.buttons["Continue"].isEnabled)

        app.press(.return)
        XCTAssertFalse(app.element("Review and Create").waitForExistence(timeout: 2))
    }
}
