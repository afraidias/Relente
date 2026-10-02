//
//  InstallerSourceTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct InstallerSourceTests {

    private func installer(_ name: String, _ version: MacOSVersion) -> InstallerSource {
        InstallerSource(
            url: URL(filePath: "/Applications/Install \(name).app"), name: name, version: version, kind: .app,
            size: 1)
    }

    @Test func `installers from Big Sur onwards are supported`() {
        #expect(installer("macOS Big Sur", "11.7.10").isSupported)
        #expect(!installer("macOS Catalina", "10.15.7").isSupported)
    }

    @Test func `newest version first`() {
        let sorted = InstallerSource.sorted([
            installer("macOS Sonoma", "14.7"), installer("macOS Tahoe", "26.0"), installer("macOS Catalina", "10.15.7"),
            installer("macOS Sequoia", "15.10"), installer("macOS Sequoia old", "15.6"),
        ])
        #expect(
            sorted.map(\.name) == [
                "macOS Tahoe", "macOS Sequoia", "macOS Sequoia old", "macOS Sonoma", "macOS Catalina",
            ])
    }

    @Test func `installers of the same version keep the order they were found in`() {
        let sorted = InstallerSource.sorted([installer("A", "15.6"), installer("B", "26.0"), installer("C", "15.6")])
        #expect(sorted.map(\.name) == ["B", "A", "C"])
    }

    @Test func `the newest supported installer is selected by default`() {
        let catalina = installer("macOS Catalina", "10.15.7")
        let sonoma = installer("macOS Sonoma", "14.7")
        let sequoia = installer("macOS Sequoia", "15.6")
        #expect(InstallerSource.defaultSelection(in: [catalina, sonoma, sequoia]) == sequoia)
    }

    @Test func `nothing is selected by default when no installer is supported`() {
        #expect(InstallerSource.defaultSelection(in: [installer("macOS Catalina", "10.15.7")]) == nil)
        #expect(InstallerSource.defaultSelection(in: []) == nil)
    }
}
