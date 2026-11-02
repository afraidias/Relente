//
//  InstallerReaderTests.swift
//  RelenteTests
//
//  Acquired installer validation uses temporary fixtures only.
//

import Foundation
import Testing

@testable import Relente

struct InstallerReaderTests {
    @Test func `bundle snapshot allows normal framework symlinks and detects content changes`() throws {
        let app = URL(filePath: "/private/tmp/Relente-Snapshot-\(UUID().uuidString).app", directoryHint: .isDirectory)
        let framework = app.appending(path: "Contents/Frameworks/Test.framework", directoryHint: .isDirectory)
        let version = framework.appending(path: "Versions/A", directoryHint: .isDirectory)
        let current = framework.appending(path: "Versions/Current")
        try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true)
        let binary = version.appending(path: "Test")
        try Data([1]).write(to: binary)
        try FileManager.default.createSymbolicLink(at: current, withDestinationURL: version)
        defer { try? FileManager.default.removeItem(at: app) }

        let first = try #require(InstallerBundleSnapshot.capture(at: app))
        try Data([1, 2]).write(to: binary)
        let second = try #require(InstallerBundleSnapshot.capture(at: app))

        #expect(first.value != second.value)
        #expect(second.size > first.size)
    }

    @Test func `an acquired app without its SharedSupport image is rejected`() async throws {
        let app = URL(filePath: "/private/tmp/Relente-Incomplete-\(UUID().uuidString).app", directoryHint: .isDirectory)
        let executable = app.appending(path: "Contents/Resources/createinstallmedia")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: executable)
        defer { try? FileManager.default.removeItem(at: app) }

        await #expect(throws: InstallerReader.ReadError.self) {
            try await InstallerReader.readAcquiredApp(at: app)
        }
    }
}
