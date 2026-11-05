//
//  AssistantFlowUITests.swift
//  RelenteUITests
//
//  The whole assistant in the running app, with sample data and the Debug-only simulation.
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
        XCTAssertTrue(app.element("Helper not installed").exists)
        XCTAssertTrue(app.buttons["Install Helper"].exists)
        XCTAssertTrue(app.buttons["Open Full Disk Access Settings…"].exists)

        app.buttons["Install Helper"].click()
        XCTAssertTrue(app.element("Helper enabled").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        app.buttons["Continue"].click()
        expectScreen("Choose an Installer")

        app.goToDone()
        expectScreen("Installer Ready")
    }

    @MainActor
    func testRevokedHelperShowsRecovery() {
        app = .relente(extraArguments: ["-sampleHelper", "revoked"])
        XCTAssertTrue(app.element("Helper disabled").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open System Settings…"].exists)
        XCTAssertTrue(
            app.element(
                "Your selections are preserved. Turn on Relente under App Background Activity in System Settings to continue."
            ).exists)
    }

    @MainActor
    func testHelperRegistrationShowsInstallingState() {
        app = .relente(extraArguments: ["-sampleHelper", "slowRegistration"])
        expectScreen("Set Up Relente")
        app.buttons["Install Helper"].click()
        XCTAssertTrue(app.element("Installing helper…").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].exists)
    }

    @MainActor
    func testHelperRegistrationFailureCanBeRetried() {
        app = .relente(extraArguments: ["-sampleHelper", "registrationFailure"])
        expectScreen("Set Up Relente")
        app.buttons["Install Helper"].click()
        XCTAssertTrue(app.element("Couldn’t install the helper").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Full Disk Access Settings…"].exists)
        app.buttons["Try Again"].click()
        XCTAssertTrue(app.element("Couldn’t install the helper").waitForExistence(timeout: 5))
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
