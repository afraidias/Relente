import Foundation
import Testing

@testable import Relente

struct InstallerArtifactStoreTests {
    @Test func `unfinished retained directories stay unavailable after relaunch`() throws {
        let root = URL(filePath: "/private/tmp").appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = InstallerArtifactStore(root: root)
        let pending = try store.makePendingDirectory()
        #expect(try store.hasPendingWork())
        #expect(InstallerArtifactStore.isUnpublished(pending.appending(path: "Install.app"), root: root))
        try FileManager.default.removeItem(at: pending)
        let retained = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: retained, withIntermediateDirectories: false)
        #expect(try store.hasPendingWork())
        #expect(InstallerArtifactStore.isUnpublished(retained.appending(path: "Install.app"), root: root))
        #expect(!InstallerArtifactStore.isUnpublished(URL(filePath: "/Applications/Install.app"), root: root))
    }

    @Test func `a ready marker alone cannot register an installer`() async throws {
        let root = URL(filePath: "/private/tmp").appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let record = InstallerArtifactStore.Record(
            schema: 1, version: "13.7.8", build: "22H730",
            appRelativePath: "../../Applications/Install.app")
        try JSONEncoder().encode(record).write(to: folder.appending(path: "ready.json"))
        let sources = try await InstallerArtifactStore(root: root).retainedSources()
        #expect(sources.isEmpty)
    }
}
