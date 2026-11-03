import Foundation
import Testing

@testable import Relente

struct LiveInstallerAcquisitionServiceTests {
    @Test func unresolvedWorkBlocksCatalogAndTransferWithoutDeletingEvidence() async throws {
        let root = URL(filePath: "/private/tmp").appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = InstallerArtifactStore(root: root)
        let pending = try store.makePendingDirectory()
        let evidence = pending.appending(path: "operation.txt")
        try Data("unfinished".utf8).write(to: evidence)
        let service = LiveInstallerAcquisitionService(
            installerService: SampleInstallerService(installers: []), store: store)
        await #expect(throws: InstallerAcquisitionError.recoveryRequired) {
            try await service.availableInstallers()
        }
        let selected = AvailableInstaller(title: "macOS Ventura", version: "13.7.8", build: "22H730")
        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) { events.append(event) }
        #expect(events.count == 1)
        guard case .failed(.recoveryRequired) = events.first else {
            Issue.record("Unresolved work must block acquisition")
            return
        }
        await service.cancelDownload()
        #expect(try Data(contentsOf: evidence) == Data("unfinished".utf8))
    }
}
