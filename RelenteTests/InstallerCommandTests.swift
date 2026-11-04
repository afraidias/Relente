import Foundation
import Testing
import os

@testable import Relente

struct InstallerCommandTests {
    @Test func cancelledCommandDoesNotLaunchOrLeaveOutput() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Relente-command-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await #expect(throws: CancellationError.self) {
                try await InstallerCommand.verifyPackage(folder.appending(path: "missing.pkg")).run(in: folder)
            }
        }
        await task.value
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func unsignedPackageReturnsTerminalFailureAndRemovesOwnedLog() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Relente-command-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let package = folder.appending(path: "InstallAssistant.pkg")
        try Data("not a signed package".utf8).write(to: package)
        await #expect(throws: InstallerCommand.Failure.self) {
            try await InstallerCommand.verifyPackage(package).run(in: folder, timeout: 10)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["InstallAssistant.pkg"])
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RELENTE_PREPARATION_PACKAGE"] != nil))
    func preparesTheResearchPackageWithoutScriptsOrInstallation() async throws {
        let text = try #require(ProcessInfo.processInfo.environment["RELENTE_PREPARATION_PACKAGE"])
        let source = URL(filePath: "/private/tmp/Relente-preparation-test-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        var cleanupSafe = false
        defer { if cleanupSafe { try? FileManager.default.removeItem(at: source) } }
        let package = source.appending(path: "InstallAssistant.pkg")
        try FileManager.default.copyItem(at: URL(filePath: text), to: package)
        let prepared = try await InstallerPackagePreparer.prepare(package)
        #expect(!FileManager.default.fileExists(atPath: prepared.temporaryDirectory.appending(path: "workspace").path))
        #expect(
            !FileManager.default.fileExists(
                atPath: prepared.temporaryDirectory.appending(path: "preparation.sparsebundle").path))
        let expected = try InstallerOSIdentity(
            version: ProcessInfo.processInfo.environment["RELENTE_PREPARATION_VERSION"] ?? "13.7.8",
            build: ProcessInfo.processInfo.environment["RELENTE_PREPARATION_BUILD"] ?? "22H730")
        let installer = try await AcquiredInstallerReader.read(prepared, expected: expected)
        #expect(installer.version.description == expected.version)
        #expect(installer.build == expected.build)
        let store = InstallerArtifactStore(root: source.appending(path: "retained"))
        let retained = try await store.commit(prepared, identity: installer)
        #expect(!InstallerArtifactStore.isUnpublished(retained.url, root: store.root))
        #expect(try !store.hasPendingWork())
        let reloaded = try await store.retainedSources()
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.version.description == expected.version)
        #expect(reloaded.first?.build == expected.build)
        #expect(reloaded.first?.packageURL == retained.packageURL)
        #expect(try !store.hasPendingWork())
        let evidence: [String: Any] = [
            "version": expected.version, "build": expected.build,
            "packageBytes": try package.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
            "nativePreparation": true, "acquiredIdentityAndCodeVerified": true,
            "retainedAndRevalidatedAfterReload": reloaded.count == 1,
            "boundedWorkspaceRemoved": !FileManager.default.fileExists(
                atPath: prepared.temporaryDirectory
                    .appending(path: "preparation.sparsebundle").path),
        ]
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(filePath: "/private/tmp/relente-preparation-proof-\(expected.build).json"))
        cleanupSafe = true
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RELENTE_PREPARATION_CANCEL_PACKAGE"] != nil))
    func realExpansionCancellationStopsBeforeRemovingItsWorkspace() async throws {
        let text = try #require(ProcessInfo.processInfo.environment["RELENTE_PREPARATION_CANCEL_PACKAGE"])
        let source = try InstallerPrivateDirectory.create()
        defer { try? FileManager.default.removeItem(at: source) }
        let package = source.appending(path: "InstallAssistant.pkg")
        try FileManager.default.copyItem(at: URL(filePath: text), to: package)
        let observed = OSAllocatedUnfairLock(initialState: Optional<URL>.none)
        await #expect(throws: InstallerPackagePreparer.PreparationError.cancelled) {
            try await InstallerPackagePreparer.prepare(
                package,
                run: { _, arguments in
                    let staged = URL(filePath: arguments[1])
                    if arguments.first == "--check-signature" {
                        return try await InstallerCommand.verifyPackage(staged).run(
                            in: staged.deletingLastPathComponent())
                    }
                    observed.withLock { $0 = staged.deletingLastPathComponent() }
                    let startedImage = staged.deletingLastPathComponent().appending(
                        path: "workspace/expanded/SharedSupport.dmg")
                    return try await InstallerExtractionWorkspace.expand(
                        package: staged,
                        destination: URL(filePath: arguments[2]),
                        isCancelled: {
                            FileManager.default.fileExists(atPath: startedImage.path)
                        })
                })
        }
        let workspace = try #require(observed.withLock { $0 })
        #expect(!FileManager.default.fileExists(atPath: workspace.path))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RELENTE_RESEARCH_PACKAGE"] != nil))
    func verifiesExplicitlyProvidedResearchPackageWithTheActualSystemTool() async throws {
        let text = try #require(ProcessInfo.processInfo.environment["RELENTE_RESEARCH_PACKAGE"])
        let package = URL(filePath: text)
        let folder = FileManager.default.temporaryDirectory.appending(path: "Relente-command-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = try await InstallerCommand.verifyPackage(package).run(in: folder, timeout: 60)
        let value = try #require(String(data: output, encoding: .utf8))
        #expect(AppleInstallerPackageSignature.acceptsSuccessfulCheck(value))
    }
}
