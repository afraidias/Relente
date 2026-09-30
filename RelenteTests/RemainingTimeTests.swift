//
//  RemainingTimeTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct RemainingTimeTests {

    /// The text in English, whatever the language of the Mac running the tests.
    private func englishText(_ remaining: RemainingTime) -> String {
        var resource = remaining.text
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    @Test func `under a minute reads less than a minute`() {
        #expect(englishText(.estimate(.seconds(0))) == "Less than a minute")
        #expect(englishText(.estimate(.seconds(59))) == "Less than a minute")
    }

    @Test func `a minute or more reads about N min, rounded to the nearest minute`() {
        #expect(englishText(.estimate(.seconds(60))) == "About 1 min")
        #expect(englishText(.estimate(.seconds(240))) == "About 4 min")
        #expect(englishText(.estimate(.seconds(269))) == "About 4 min")
        #expect(englishText(.estimate(.seconds(271))) == "About 5 min")
    }

    @Test func `over an hour shows hours and minutes`() {
        let text = englishText(.estimate(.seconds(80 * 60)))
        #expect(text.hasPrefix("About 1"))
        #expect(text.contains("20"))
    }

    @Test func `calculating and almost done`() {
        #expect(englishText(.calculating) == "Calculating…")
        #expect(englishText(.almostDone) == "Almost done")
    }
}
