//
//  SampleInstallerService.swift
//  Relente
//
//  Installers for previews, tests and `-sampleData YES`: never reads the Mac's files. Tests
//  change the list with `send(_:)`.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated final class SampleInstallerService: InstallerService {
    private let initial: [InstallerSource]
    /// What `add` returns for each file; any other file isn't an installer.
    private let choosable: [URL: InstallerSource]
    private let stream: AsyncStream<[InstallerSource]>
    private let continuation: AsyncStream<[InstallerSource]>.Continuation

    init(installers: [InstallerSource] = InstallerSource.samples, choosable: [InstallerSource] = []) {
        initial = installers
        self.choosable = Dictionary(choosable.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.yield(installers)
    }

    /// One stream for the app's one assistant.
    func updates() -> AsyncStream<[InstallerSource]> {
        stream
    }

    func add(_ url: URL) async throws(InstallerError) -> InstallerSource {
        guard let installer = choosable[url] else { throw .notAnInstaller(fileName: url.lastPathComponent) }
        return installer
    }

    /// Replaces the list, as if installers appeared or disappeared.
    func send(_ installers: [InstallerSource]) {
        continuation.yield(installers)
    }
}
