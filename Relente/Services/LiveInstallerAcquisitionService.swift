//
//  LiveInstallerAcquisitionService.swift
//  Relente
//
//  Loads Apple's full installer catalog through the fixed softwareupdate tool.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation
import os

actor LiveInstallerAcquisitionService: InstallerAcquisitionService {
    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "installer")
    private static let softwareUpdate = URL(filePath: "/usr/sbin/softwareupdate")
    private let runner: any SoftwareUpdateRunning
    private let installerService: any InstallerService
    private let destinationExists: @Sendable (URL) -> Bool
    private let readInstaller: @Sendable (URL) async throws -> InstallerSource
    private let incompleteInstallerAt: @Sendable (URL) async -> IncompleteInstaller?
    private let moveIncompleteInstaller: @Sendable (IncompleteInstaller) async -> IncompleteInstallerTrashOutcome?
    private var activeTask: Task<Void, Never>?
    private var activeContinuation: AsyncStream<InstallerAcquisitionEvent>.Continuation?
    private var cancellationRequested = false

    init(
        runner: any SoftwareUpdateRunning = ProcessSoftwareUpdateRunner(),
        installerService: any InstallerService = LiveInstallerService(),
        readInstaller: @escaping @Sendable (URL) async throws -> InstallerSource = {
            try await InstallerReader.readAcquiredApp(at: $0)
        },
        incompleteInstallerAt: @escaping @Sendable (URL) async -> IncompleteInstaller? = {
            await InstallerReader.incompleteAcquiredApp(at: $0)
        },
        moveIncompleteInstaller: @escaping @Sendable (IncompleteInstaller) async -> IncompleteInstallerTrashOutcome? = {
            await LiveHelperClient().moveIncompleteInstallerToTrash($0)
        },
        destinationExists: @escaping @Sendable (URL) -> Bool = {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    ) {
        self.runner = runner
        self.installerService = installerService
        self.readInstaller = readInstaller
        self.incompleteInstallerAt = incompleteInstallerAt
        self.moveIncompleteInstaller = moveIncompleteInstaller
        self.destinationExists = destinationExists
    }

    func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller] {
        let result: SoftwareUpdateCommandResult
        do {
            result = try await runner.run(executable: Self.softwareUpdate, arguments: ["--list-full-installers"])
        } catch {
            throw .catalogUnavailable
        }
        guard result.exitCode == 0 else { throw .catalogUnavailable }

        do {
            return try SoftwareUpdateOutputParser.fullInstallers(from: result.output).filter(\.isSupported)
        } catch {
            throw .catalogUnavailable
        }
    }

    func incompleteInstallers() async -> [IncompleteInstaller] {
        guard activeTask == nil else { return [] }
        let applications = URL(filePath: "/Applications", directoryHint: .isDirectory)
        guard
            let items = try? FileManager.default.contentsOfDirectory(
                at: applications, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        else { return [] }

        var incomplete: [IncompleteInstaller] = []
        for item in items where item.pathExtension == "app" && item.lastPathComponent.hasPrefix("Install macOS ") {
            guard let candidate = await InstallerReader.incompleteAcquiredApp(at: item) else { continue }
            incomplete.append(candidate)
        }
        return activeTask == nil ? incomplete.sorted { $0.version > $1.version } : []
    }

    func moveToTrash(_ installer: IncompleteInstaller) async throws(IncompleteInstallerError) {
        guard activeTask == nil else { throw .downloadActive }
        guard let current = await incompleteInstallerAt(installer.url),
            current == installer,
            activeTask == nil
        else { throw .changed }
        switch await moveIncompleteInstaller(current) {
        case .moved:
            return
        case .changed:
            throw .changed
        case .refused, .failed, .none:
            Self.logger.error("Helper could not move the confirmed incomplete installer to the caller's Trash")
            throw .moveFailed
        }
    }

    /// Refreshes Apple's list and the local installer watcher before permitting a download.
    func decision(for selected: AvailableInstaller) async throws(InstallerAcquisitionError)
        -> InstallerAcquisitionPolicy.Decision
    {
        let catalog = try await availableInstallers()
        return await decision(for: selected, catalog: catalog)
    }

    private func decision(for selected: AvailableInstaller, catalog: [AvailableInstaller]) async
        -> InstallerAcquisitionPolicy.Decision
    {
        let updates = installerService.updates()
        var iterator = updates.makeAsyncIterator()
        guard let local = await iterator.next() else { return .unavailable(.localStateUnavailable) }

        return InstallerAcquisitionPolicy.decision(
            for: selected,
            among: catalog,
            localInstallers: local,
            destinationOccupied: destinationExists(InstallerAcquisitionPolicy.destination(for: selected))
        )
    }

    func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: InstallerAcquisitionEvent.self)
        guard activeTask == nil else {
            continuation.yield(.failed(.alreadyDownloading))
            continuation.finish()
            return stream
        }

        activeContinuation = continuation
        cancellationRequested = false
        activeTask = Task {
            await performDownload(installer)
        }
        return stream
    }

    func cancelDownload() async {
        cancellationRequested = true
        await runner.cancel()
    }

    private func performDownload(_ installer: AvailableInstaller) async {
        let catalog: [AvailableInstaller]
        let acquisitionDecision: InstallerAcquisitionPolicy.Decision
        do {
            catalog = try await availableInstallers()
            acquisitionDecision = await decision(for: installer, catalog: catalog)
        } catch {
            finish(.failed(error))
            return
        }

        switch acquisitionDecision {
        case .use(let source):
            finish(.completed(source))
        case .unavailable(let reason):
            finish(.blocked(reason))
        case .download:
            let destination = InstallerAcquisitionPolicy.destination(for: installer)
            await installerService.setAcquisitionInProgress(destination)
            let lastDecision = await decision(for: installer, catalog: catalog)
            switch lastDecision {
            case .use(let source):
                await installerService.setAcquisitionInProgress(nil)
                finish(.completed(source))
                return
            case .unavailable(let reason):
                await installerService.setAcquisitionInProgress(nil)
                finish(.blocked(reason))
                return
            case .download:
                break
            }
            if cancellationRequested {
                await installerService.setAcquisitionInProgress(nil)
                finish(.cancelled)
                return
            }
            let events = await runner.stream(
                executable: Self.softwareUpdate,
                arguments: ["--fetch-full-installer", "--full-installer-version", installer.version.description]
            )
            if cancellationRequested { await runner.cancel() }
            var processFinished = false
            for await event in events {
                switch event {
                case .output(let line):
                    activeContinuation?.yield(.output(CreationOutputLine(timestamp: .now, text: line)))
                    if let progress = SoftwareUpdateOutputParser.reportedProgress(in: line) {
                        activeContinuation?.yield(.progress(progress))
                    }
                case .failed:
                    await installerService.setAcquisitionInProgress(nil)
                    finish(.failed(.downloadFailed))
                    return
                case .finished(let exitCode, let wasCancelled):
                    processFinished = true
                    if wasCancelled {
                        await installerService.setAcquisitionInProgress(nil)
                        finish(.cancelled)
                    } else if exitCode != 0 {
                        await installerService.setAcquisitionInProgress(nil)
                        finish(.failed(.downloadFailed))
                    } else {
                        await addCompletedInstaller(installer)
                    }
                }
            }
            if !processFinished {
                await installerService.setAcquisitionInProgress(nil)
                finish(.failed(.downloadFailed))
            }
        }
    }

    private func addCompletedInstaller(_ installer: AvailableInstaller) async {
        let url = InstallerAcquisitionPolicy.destination(for: installer)
        do {
            let read = try await readInstaller(url)
            guard read.version == installer.version,
                installer.build == nil || read.build == nil || installer.build == read.build
            else {
                await installerService.setAcquisitionInProgress(nil)
                finish(.failed(.downloadFailed))
                return
            }
            let complete = try await installerService.add(url)
            await installerService.setAcquisitionInProgress(nil)
            finish(.completed(complete))
        } catch {
            await installerService.setAcquisitionInProgress(nil)
            finish(.failed(.downloadFailed))
        }
    }

    private func finish(_ event: InstallerAcquisitionEvent) {
        activeContinuation?.yield(event)
        activeContinuation?.finish()
        activeContinuation = nil
        activeTask = nil
        cancellationRequested = false
    }
}
