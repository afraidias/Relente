//
//  AssistantNavigation.swift
//  RelenteUITests
//
//  Shared steps for the UI tests: opening the app and walking the assistant to a screen, with
//  sample data and the Debug-only simulated creation.
//  Spec: specs/006-assistant-navigation/spec.md
//

import XCTest

extension XCUIApplication {

    /// Launches Relente in English whatever the language of the Mac running the tests.
    /// `simulationSpeed` "fast" makes the simulated creation last about 2 s.
    @MainActor
    static func relente(simulationSpeed: String = "normal", extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // A fresh window each time: ignore the windows macOS saved from the last run.
        app.launchArguments =
            [
                "-simulationSpeed", simulationSpeed, "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-ApplePersistenceIgnoreState", "YES",
            ] + extraArguments
        app.launch()
        return app
    }

    /// Any element whose label or value is `text`. Screen titles are headings for VoiceOver, so
    /// they aren't plain static texts.
    @MainActor
    func element(_ text: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "value == %@ OR label == %@", text, text))
            .firstMatch
    }

    @MainActor
    func press(_ key: XCUIKeyboardKey) {
        windows.firstMatch.typeKey(key, modifierFlags: [])
    }

    /// From the Installer screen to Review with the keyboard: Return, an arrow to pick the first
    /// drive (SanDisk Ultra), Return.
    @MainActor
    func goToReview(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element("Choose an Installer").waitForExistence(timeout: 5), file: file, line: line)
        press(.return)
        XCTAssertTrue(element("Choose a USB Drive").waitForExistence(timeout: 5), file: file, line: line)
        press(.rightArrow)
        press(.return)
        XCTAssertTrue(element("Review and Create").waitForExistence(timeout: 5), file: file, line: line)
    }

    /// From the Installer screen to Creating: Review, confirm, "Erase and Create".
    @MainActor
    func startCreating(file: StaticString = #filePath, line: UInt = #line) {
        goToReview(file: file, line: line)
        checkBoxes.firstMatch.click()
        buttons["Erase and Create"].click()
        XCTAssertTrue(element("Creating Installer").waitForExistence(timeout: 5), file: file, line: line)
    }

    /// From the Installer screen to Done. Needs the fast simulation.
    @MainActor
    func goToDone(file: StaticString = #filePath, line: UInt = #line) {
        startCreating(file: file, line: line)
        XCTAssertTrue(element("Installer Ready").waitForExistence(timeout: 15), file: file, line: line)
    }
}
