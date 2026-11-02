//
//  InstallerAcquisitionServiceTests.swift
//  RelenteTests
//
//  Sample acquisition never accesses Apple's services or the file system.
//

import Foundation
import Testing

@testable import Relente

struct InstallerAcquisitionServiceTests {
    @Test func `sample lists newest supported installers first`() async throws {
        let service = SampleInstallerAcquisitionService()
        let installers = try await service.availableInstallers()

        #expect(installers.map(\.version) == ["26.1", "26.0", "15.6"])
    }

    @Test func `sample download reports progress and a completed installer`() async {
        let service = SampleInstallerAcquisitionService()
        let installer = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")
        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(installer) {
            events.append(event)
        }

        #expect(events.contains(.progress(0.25)))
        #expect(
            events.contains(
                .completed(
                    InstallerSource(
                        url: URL(filePath: "/Applications/Install macOS Tahoe.app"),
                        name: "macOS Tahoe",
                        version: "26.0",
                        kind: .app,
                        size: 16_800_000_000,
                        build: "25A354"
                    ))))
    }

    @Test func `sample download can be cancelled`() async {
        let service = SampleInstallerAcquisitionService(downloadDelay: .seconds(5))
        let installer = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")
        var iterator = await service.download(installer).makeAsyncIterator()

        #expect(await iterator.next() == .progress(0.25))
        await service.cancelDownload()
        #expect(await iterator.next() == .cancelled)
    }

    @Test func `sample exposes catalog and download errors`() async {
        let catalog = SampleInstallerAcquisitionService(catalogError: .catalogUnavailable)
        await #expect(throws: InstallerAcquisitionError.catalogUnavailable) {
            try await catalog.availableInstallers()
        }

        let service = SampleInstallerAcquisitionService(downloadError: .downloadFailed)
        let installer = AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")
        var lastEvent: InstallerAcquisitionEvent?
        for await event in await service.download(installer) {
            lastEvent = event
        }
        #expect(lastEvent == .failed(.downloadFailed))
    }
}
