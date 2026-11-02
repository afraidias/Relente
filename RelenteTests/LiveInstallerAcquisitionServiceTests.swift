//
//  LiveInstallerAcquisitionServiceTests.swift
//  RelenteTests
//
//  The injected runner keeps tests away from Apple's update service.
//

import Foundation
import Testing

@testable import Relente

struct LiveInstallerAcquisitionServiceTests {
    @Test func `catalog uses Apple's fixed executable and full installer argument`() async throws {
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(
                exitCode: 0,
                output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84\nTitle: macOS Catalina, Version: 10.15.7"
            ))
        let service = LiveInstallerAcquisitionService(runner: runner)

        let installers = try await service.availableInstallers()
        let command = await runner.command

        #expect(command?.executable == URL(filePath: "/usr/sbin/softwareupdate"))
        #expect(command?.arguments == ["--list-full-installers"])
        #expect(installers == [AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")])
    }

    @Test func `empty catalog is a successful empty list`() async throws {
        let runner = RecordingSoftwareUpdateRunner(result: .init(exitCode: 0, output: "No new software available."))
        let service = LiveInstallerAcquisitionService(runner: runner)

        #expect(try await service.availableInstallers().isEmpty)
    }

    @Test func `malformed catalog output is recoverable error`() async {
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Future, Version: ???"))
        let service = LiveInstallerAcquisitionService(runner: runner)

        await #expect(throws: InstallerAcquisitionError.catalogUnavailable) {
            try await service.availableInstallers()
        }
    }

    @Test func `nonzero command status is a recoverable error`() async {
        let runner = RecordingSoftwareUpdateRunner(result: .init(exitCode: 1, output: "network unavailable"))
        let service = LiveInstallerAcquisitionService(runner: runner)

        await #expect(throws: InstallerAcquisitionError.catalogUnavailable) {
            try await service.availableInstallers()
        }
    }

    @Test func `confirmed unchanged incomplete installer is recycled`() async throws {
        let installer = incompleteInstaller()
        let mover = TrashMoveRecorder()
        let service = LiveInstallerAcquisitionService(
            incompleteInstallerAt: { _ in installer },
            moveIncompleteInstaller: { await mover.run($0) }
        )

        try await service.moveToTrash(installer)

        #expect(await mover.installer == installer)
    }

    @Test func `changed incomplete installer is not recycled`() async {
        let installer = incompleteInstaller()
        let mover = TrashMoveRecorder()
        let service = LiveInstallerAcquisitionService(
            incompleteInstallerAt: { _ in nil },
            moveIncompleteInstaller: { await mover.run($0) }
        )

        await #expect(throws: IncompleteInstallerError.changed) {
            try await service.moveToTrash(installer)
        }

        #expect(await mover.installer == nil)
    }

    @Test func `Finder recycle failure remains a cleanup error`() async {
        let installer = incompleteInstaller()
        let service = LiveInstallerAcquisitionService(
            incompleteInstallerAt: { _ in installer },
            moveIncompleteInstaller: { _ in .failed }
        )

        await #expect(throws: IncompleteInstallerError.moveFailed) {
            try await service.moveToTrash(installer)
        }
    }

    @Test func `incomplete installer cannot be recycled during a download`() async {
        let installer = incompleteInstaller()
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let runner = HeldSoftwareUpdateRunner(
            catalogOutput: "Title: macOS Sequoia, Version: 15.6, Build: 24G84")
        let mover = TrashMoveRecorder()
        let service = LiveInstallerAcquisitionService(
            runner: runner,
            installerService: FixedInstallerService(installers: []),
            incompleteInstallerAt: { _ in installer },
            moveIncompleteInstaller: { await mover.run($0) },
            destinationExists: { _ in false }
        )
        var download = await service.download(selected).makeAsyncIterator()
        let output = await download.next()
        if case .output(let line) = output {
            #expect(line.text == "Downloading: 20%")
        } else {
            #expect(Bool(false))
        }
        #expect(await download.next() == .progress(0.2))

        await #expect(throws: IncompleteInstallerError.downloadActive) {
            try await service.moveToTrash(installer)
        }

        await service.cancelDownload()
        #expect(await download.next() == .cancelled)
        #expect(await mover.installer == nil)
    }

    @Test func `a local installer found immediately before download is reused`() async throws {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let local = InstallerSource(
            url: URL(filePath: "/Users/Shared/Sequoia.app"), name: selected.title, version: selected.version,
            kind: .app, size: 15_200_000_000, build: selected.build)
        let service = LiveInstallerAcquisitionService(
            runner: RecordingSoftwareUpdateRunner(
                result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84")),
            installerService: FixedInstallerService(installers: [local]),
            destinationExists: { _ in true }
        )

        #expect(try await service.decision(for: selected) == .use(local))
    }

    @Test func `an unreadable occupied Apple destination blocks download`() async throws {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let service = LiveInstallerAcquisitionService(
            runner: RecordingSoftwareUpdateRunner(
                result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84")),
            installerService: FixedInstallerService(installers: []),
            destinationExists: { url in url.path == "/Applications/Install macOS Sequoia.app" }
        )

        #expect(try await service.decision(for: selected) == .unavailable(.destinationOccupied))
    }

    @Test func `download streams reported progress and only completes a verified installer`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let source = InstallerSource(
            url: URL(filePath: "/Applications/Install macOS Sequoia.app"), name: selected.title,
            version: selected.version, kind: .app, size: 15_200_000_000, build: selected.build)
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84"),
            downloadEvents: [.output("Installing: 35%"), .finished(exitCode: 0, wasCancelled: false)]
        )
        let service = LiveInstallerAcquisitionService(
            runner: runner,
            installerService: FixedInstallerService(installers: [], addedInstaller: source),
            readInstaller: { _ in source },
            destinationExists: { _ in false }
        )
        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) {
            events.append(event)
        }

        #expect(events.count == 3)
        if case .output(let line) = events.first {
            #expect(line.text == "Installing: 35%")
        } else {
            #expect(Bool(false))
        }
        #expect(events.dropFirst() == [.progress(0.35), .completed(source)])
        #expect(await runner.catalogCalls == 1)
        #expect(await runner.downloadArguments == ["--fetch-full-installer", "--full-installer-version", "15.6"])
    }

    @Test func `an installer appearing during preparation is reused without another catalog request`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let local = InstallerSource(
            url: URL(filePath: "/Users/Shared/Sequoia.app"), name: selected.title, version: selected.version,
            kind: .app, size: 15_200_000_000, build: selected.build)
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84"))
        let service = LiveInstallerAcquisitionService(
            runner: runner, installerService: AppearingInstallerService(installer: local),
            destinationExists: { _ in false })

        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) { events.append(event) }

        #expect(events == [.completed(local)])
        #expect(await runner.catalogCalls == 1)
        #expect(await runner.downloadArguments == nil)
    }

    @Test func `a destination occupied during preparation blocks the download`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84"))
        let destination = DestinationAppears()
        let service = LiveInstallerAcquisitionService(
            runner: runner, installerService: FixedInstallerService(installers: []),
            destinationExists: { _ in destination.isOccupied() })

        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) { events.append(event) }

        #expect(events == [.blocked(.destinationOccupied)])
        #expect(await runner.catalogCalls == 1)
        #expect(await runner.downloadArguments == nil)
    }

    @Test func `duplicate downloads are blocked and cancellation waits for process exit`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let runner = HeldSoftwareUpdateRunner(
            catalogOutput: "Title: macOS Sequoia, Version: 15.6, Build: 24G84")
        let service = LiveInstallerAcquisitionService(
            runner: runner,
            installerService: FixedInstallerService(installers: []),
            destinationExists: { _ in false }
        )
        var first = await service.download(selected).makeAsyncIterator()
        let output = await first.next()
        if case .output(let line) = output {
            #expect(line.text == "Downloading: 20%")
        } else {
            #expect(Bool(false))
        }
        #expect(await first.next() == .progress(0.2))

        var duplicate = await service.download(selected).makeAsyncIterator()
        #expect(await duplicate.next() == .failed(.alreadyDownloading))

        await service.cancelDownload()
        #expect(await first.next() == .cancelled)
        #expect(await runner.cancelWasCalled)
    }

    @Test func `failed command with no reported progress remains a failure`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84"),
            downloadEvents: [.output("Preparing installer"), .finished(exitCode: 1, wasCancelled: false)]
        )
        let service = LiveInstallerAcquisitionService(
            runner: runner,
            installerService: FixedInstallerService(installers: []),
            readInstaller: { _ in throw InstallerAcquisitionError.downloadFailed },
            destinationExists: { _ in false }
        )
        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) {
            events.append(event)
        }

        #expect(events.count == 2)
        if case .output(let line) = events.first {
            #expect(line.text == "Preparing installer")
        } else {
            #expect(Bool(false))
        }
        #expect(events.last == .failed(.downloadFailed))
    }

    @Test func `an unreadable result is never added or reported complete`() async {
        let selected = AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84")
        let runner = RecordingSoftwareUpdateRunner(
            result: .init(exitCode: 0, output: "Title: macOS Sequoia, Version: 15.6, Build: 24G84"),
            downloadEvents: [.finished(exitCode: 0, wasCancelled: false)]
        )
        let service = LiveInstallerAcquisitionService(
            runner: runner,
            installerService: FixedInstallerService(installers: []),
            readInstaller: { _ in throw InstallerAcquisitionError.downloadFailed },
            destinationExists: { _ in false }
        )
        var events: [InstallerAcquisitionEvent] = []
        for await event in await service.download(selected) {
            events.append(event)
        }

        #expect(events == [.failed(.downloadFailed)])
    }
}

private func incompleteInstaller() -> IncompleteInstaller {
    IncompleteInstaller(
        url: URL(filePath: "/Applications/Install macOS Big Sur.app"),
        name: "macOS Big Sur",
        version: "11.7.10",
        sizeInBytes: 40_200_000,
        snapshot: "unchanged"
    )
}

private actor TrashMoveRecorder {
    private(set) var installer: IncompleteInstaller?

    func run(_ installer: IncompleteInstaller) -> IncompleteInstallerTrashOutcome {
        self.installer = installer
        return .moved
    }
}

private actor RecordingSoftwareUpdateRunner: SoftwareUpdateRunning {
    struct Command: Sendable {
        let executable: URL
        let arguments: [String]
    }

    private let result: SoftwareUpdateCommandResult
    private let downloadEvents: [SoftwareUpdateCommandEvent]
    private(set) var command: Command?
    private(set) var catalogCalls = 0
    private(set) var downloadArguments: [String]?

    init(result: SoftwareUpdateCommandResult, downloadEvents: [SoftwareUpdateCommandEvent] = []) {
        self.result = result
        self.downloadEvents = downloadEvents
    }

    func run(executable: URL, arguments: [String]) async throws(SoftwareUpdateRunError)
        -> SoftwareUpdateCommandResult
    {
        command = Command(executable: executable, arguments: arguments)
        catalogCalls += 1
        return result
    }

    func stream(executable: URL, arguments: [String]) async -> AsyncStream<SoftwareUpdateCommandEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SoftwareUpdateCommandEvent.self)
        downloadArguments = arguments
        for event in downloadEvents {
            continuation.yield(event)
        }
        continuation.finish()
        return stream
    }

    func cancel() async {}
}

private actor AppearingInstallerService: InstallerService {
    let installer: InstallerSource
    private var appeared = false

    init(installer: InstallerSource) { self.installer = installer }

    nonisolated func updates() -> AsyncStream<[InstallerSource]> {
        AsyncStream { continuation in
            Task {
                continuation.yield(await self.snapshot())
                continuation.finish()
            }
        }
    }

    private func snapshot() -> [InstallerSource] { appeared ? [installer] : [] }

    func setAcquisitionInProgress(_ url: URL?) async { appeared = url != nil }

    func add(_ url: URL) async throws(InstallerError) -> InstallerSource { installer }
}

private nonisolated final class DestinationAppears: @unchecked Sendable {
    private let lock = NSLock()
    private var checks = 0

    func isOccupied() -> Bool {
        lock.withLock {
            checks += 1
            return checks > 1
        }
    }
}

private struct FixedInstallerService: InstallerService {
    let installers: [InstallerSource]
    var addedInstaller: InstallerSource?

    func updates() -> AsyncStream<[InstallerSource]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [InstallerSource].self)
        continuation.yield(installers)
        continuation.finish()
        return stream
    }

    func add(_ url: URL) async throws(InstallerError) -> InstallerSource {
        if let addedInstaller, addedInstaller.url.path == url.path { return addedInstaller }
        throw .notAnInstaller(fileName: url.lastPathComponent)
    }

    func setAcquisitionInProgress(_ url: URL?) async {}
}

private actor HeldSoftwareUpdateRunner: SoftwareUpdateRunning {
    private let catalogOutput: String
    private var continuation: AsyncStream<SoftwareUpdateCommandEvent>.Continuation?
    private(set) var cancelWasCalled = false

    init(catalogOutput: String) {
        self.catalogOutput = catalogOutput
    }

    func run(executable: URL, arguments: [String]) async throws(SoftwareUpdateRunError)
        -> SoftwareUpdateCommandResult
    {
        .init(exitCode: 0, output: catalogOutput)
    }

    func stream(executable: URL, arguments: [String]) async -> AsyncStream<SoftwareUpdateCommandEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SoftwareUpdateCommandEvent.self)
        self.continuation = continuation
        continuation.yield(.output("Downloading: 20%"))
        return stream
    }

    func cancel() async {
        cancelWasCalled = true
        continuation?.yield(.finished(exitCode: 130, wasCancelled: true))
        continuation?.finish()
        continuation = nil
    }
}
