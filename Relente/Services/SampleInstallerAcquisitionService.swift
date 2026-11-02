//
//  SampleInstallerAcquisitionService.swift
//  Relente
//
//  Predictable catalog and download results for previews and tests; never runs commands or uses
//  the network.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

actor SampleInstallerAcquisitionService: InstallerAcquisitionService {
    private let installers: [AvailableInstaller]
    private let catalogError: InstallerAcquisitionError?
    private let downloadError: InstallerAcquisitionError?
    private let downloadDelay: Duration
    private var activeTask: Task<Void, Never>?
    private var activeContinuation: AsyncStream<InstallerAcquisitionEvent>.Continuation?

    init(
        installers: [AvailableInstaller] = [
            AvailableInstaller(title: "macOS Tahoe", version: "26.1", build: "25B354"),
            AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354"),
            AvailableInstaller(title: "macOS Sequoia", version: "15.6", build: "24G84"),
        ],
        catalogError: InstallerAcquisitionError? = nil,
        downloadError: InstallerAcquisitionError? = nil,
        downloadDelay: Duration = .milliseconds(30)
    ) {
        self.installers = AvailableInstaller.sorted(installers)
        self.catalogError = catalogError
        self.downloadError = downloadError
        self.downloadDelay = downloadDelay
    }

    func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller] {
        if let catalogError { throw catalogError }
        return installers
    }

    func incompleteInstallers() async -> [IncompleteInstaller] { [] }

    func moveToTrash(_ installer: IncompleteInstaller) async throws(IncompleteInstallerError) {
        throw .changed
    }

    func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: InstallerAcquisitionEvent.self)
        guard activeTask == nil else {
            continuation.yield(.failed(.alreadyDownloading))
            continuation.finish()
            return stream
        }

        activeContinuation = continuation
        activeTask = Task {
            continuation.yield(.progress(0.25))
            do {
                try await Task.sleep(for: downloadDelay)
                if Task.isCancelled {
                    finish(.cancelled)
                } else if let downloadError {
                    finish(.failed(downloadError))
                } else if let source = Self.sampleSource(for: installer) {
                    continuation.yield(.progress(1))
                    finish(.completed(source))
                } else {
                    finish(.failed(.downloadFailed))
                }
            } catch {
                finish(.cancelled)
            }
        }
        return stream
    }

    func cancelDownload() async {
        activeTask?.cancel()
    }

    private func finish(_ event: InstallerAcquisitionEvent) {
        activeContinuation?.yield(event)
        activeContinuation?.finish()
        activeContinuation = nil
        activeTask = nil
    }

    private static func sampleSource(for installer: AvailableInstaller) -> InstallerSource? {
        guard installer.isSupported else { return nil }
        return InstallerSource(
            url: URL(filePath: "/Applications/Install \(installer.title).app"),
            name: installer.title,
            version: installer.version,
            kind: .app,
            size: 16_800_000_000,
            build: installer.build
        )
    }
}
