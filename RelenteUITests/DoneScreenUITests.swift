//
//  DoneScreenUITests.swift
//  RelenteUITests
//
//  What VoiceOver reads on the Done screen, in the running app. Done is reached by walking the
//  assistant with the Debug-only fast simulation (Tahoe on the SanDisk Ultra).
//  Specs: specs/005-done-screen/spec.md, specs/006-assistant-navigation/spec.md
//

import XCTest

final class DoneScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Opens the app and walks to Done.
    @MainActor
    private func launch() {
        app = .relente(simulationSpeed: "fast")
        app.goToDone()
    }

    /// Elements whose accessibility label matches, anywhere in the window.
    @MainActor
    private func elements(_ format: String, _ argument: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: format, argument))
    }

    /// Texts in the help popover, which macOS exposes as the value of a static text.
    @MainActor
    private func popoverText(beginningWith text: String) -> XCUIElement {
        app.popovers.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", text)).firstMatch
    }

    @MainActor
    func testTheDriveReadsAsOneElementWithItsNewName() {
        launch()
        let hero = elements("label == %@", "Install macOS Tahoe, on SanDisk Ultra").firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
    }

    @MainActor
    func testEachCardReadsAsOneSentenceAndOnlyOneIsThisMac() {
        launch()
        let appleSilicon = elements("label BEGINSWITH %@", "Apple silicon").firstMatch
        XCTAssertTrue(appleSilicon.waitForExistence(timeout: 5))
        XCTAssertTrue(
            appleSilicon.label.hasSuffix(
                "Hold the power button until you see the start-up options, then choose “Install macOS Tahoe”."))

        let intel = elements("label BEGINSWITH %@", "Intel").firstMatch
        XCTAssertTrue(intel.exists)
        XCTAssertTrue(
            intel.label.hasSuffix("Hold Option (⌥) right after turning on the Mac, then choose “Install macOS Tahoe”."))

        let thisMacCards = [appleSilicon, intel].filter { $0.label.contains(", this Mac:") }
        XCTAssertEqual(thisMacCards.count, 1)
    }

    @MainActor
    func testTheKeyStripsAreNotRead() {
        launch()
        XCTAssertTrue(app.buttons["Eject"].waitForExistence(timeout: 5))
        for key in ["F10", "F11", "F12", "fn", "control", "option", "command"] {
            XCTAssertFalse(elements("label == %@", key).firstMatch.exists, "“\(key)” should not be read")
        }
    }

    @MainActor
    func testHelpOpensThePopoverAndEscClosesIt() {
        launch()
        let help = app.buttons["Help"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.click()
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
        XCTAssertTrue(popoverText(beginningWith: "Drive not showing up at start-up?").exists)
        // Each cause reads as one element: its title, then what to do.
        XCTAssertTrue(popoverText(beginningWith: "Connection, Plug it straight into the Mac").exists)
        XCTAssertTrue(popoverText(beginningWith: "Intel Mac with the T2 chip (2018–2020), Start up in Recovery").exists)
        XCTAssertTrue(
            popoverText(beginningWith: "Compatibility, It only shows up on Macs that support macOS Tahoe").exists)

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(popover.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testEjectIsTheOnlyButtonBesidesHelp() {
        launch()
        XCTAssertTrue(app.buttons["Eject"].waitForExistence(timeout: 5))
        let otherButtons = app.windows.firstMatch.buttons.allElementsBoundByIndex.filter {
            !["Eject", "Help"].contains($0.label) && !$0.identifier.hasPrefix("_XCUI")
        }
        // The window's own close, minimize and zoom buttons are the only others.
        XCTAssertLessThanOrEqual(otherButtons.count, 3, otherButtons.map(\.label).description)
    }

    @MainActor
    func testTheSimulationIsLabelled() {
        launch()
        XCTAssertTrue(app.element("SIMULATION · Nothing is erased").exists)
    }
}
