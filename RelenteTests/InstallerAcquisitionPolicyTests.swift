//
//  InstallerAcquisitionPolicyTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct InstallerAcquisitionPolicyTests {
    private let tahoe = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")

    @Test func `unique local exact match is reused before destination checks`() {
        let existing = InstallerSource(
            url: InstallerSource.samples[0].url, name: "macOS Tahoe", version: "26.0", kind: .app,
            size: 16_800_000_000, build: "25A354")
        let decision = InstallerAcquisitionPolicy.decision(
            for: tahoe,
            among: [tahoe],
            localInstallers: [existing],
            destinationOccupied: true
        )

        #expect(decision == .use(existing))
    }

    @Test func `different known local build is not reused`() {
        let differentBuild = InstallerSource(
            url: InstallerSource.samples[0].url, name: "macOS Tahoe", version: "26.0", kind: .app,
            size: 16_800_000_000, build: "25A355")

        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [tahoe], localInstallers: [differentBuild], destinationOccupied: true
            ) == .unavailable(.destinationOccupied))
    }

    @Test func `stale catalog selection is rejected`() {
        let refreshed = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A355")

        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [refreshed], localInstallers: [], destinationOccupied: false
            ) == .unavailable(.catalogChanged))
    }

    @Test func `multiple local matches are returned for manual resolution`() {
        let first = InstallerSource.samples[0]
        let second = InstallerSource(
            url: URL(filePath: "/Users/Shared/Install macOS Tahoe.app"), name: first.name, version: first.version,
            kind: .app, size: first.size, build: first.build)

        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [tahoe], localInstallers: [first, second], destinationOccupied: false
            ) == .unavailable(.multipleLocalMatches))
    }

    @Test func `distinct catalog builds block a download when no local match exists`() {
        let otherBuild = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A355")

        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [tahoe, otherBuild], localInstallers: [], destinationOccupied: false
            ) == .unavailable(.ambiguousBuild))
    }

    @Test func `occupied destination blocks download`() {
        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [tahoe], localInstallers: [], destinationOccupied: true
            ) == .unavailable(.destinationOccupied))
    }

    @Test func `clear destination permits a unique catalog build`() {
        #expect(
            InstallerAcquisitionPolicy.decision(
                for: tahoe, among: [tahoe], localInstallers: [], destinationOccupied: false
            ) == .download)
    }

    @Test func `different version destination does not block selected installer`() {
        let sequoia = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")

        #expect(
            InstallerAcquisitionPolicy.decision(
                for: sequoia, among: [sequoia], localInstallers: [], destinationOccupied: false
            ) == .download)
        #expect(InstallerAcquisitionPolicy.destination(for: sequoia).path == "/Applications/Install macOS Sequoia.app")
    }
}
