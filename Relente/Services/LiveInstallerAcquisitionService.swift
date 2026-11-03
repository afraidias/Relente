import Foundation
import os

actor LiveInstallerAcquisitionService: InstallerAcquisitionService {
    private let installerService: any InstallerService
    private let catalog = AppleInstallerCatalog()
    private let store: InstallerArtifactStore
    private let logger = Logger(subsystem: "com.afraidias.Relente", category: "installer")
    private var entries: [AppleInstallerProduct.Resolved] = []
    private var recovered = false
    private var blockedForRecovery = false
    private var refreshing = false
    private var publishing = false
    private var job: Task<Void, Never>?
    private var continuation: AsyncStream<InstallerAcquisitionEvent>.Continuation?

    init(installerService: any InstallerService, store: InstallerArtifactStore = InstallerArtifactStore()) {
        self.installerService = installerService
        self.store = store
    }

    func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller] {
        do {
            if !recovered {
                guard try !store.hasPendingWork() else {
                    blockedForRecovery = true
                    throw InstallerAcquisitionError.recoveryRequired
                }
                for source in try await store.retainedSources() { _ = try await installerService.addRetained(source) }
                blockedForRecovery = try store.hasPendingWork()
                recovered = true
            }
            guard !blockedForRecovery else { throw InstallerAcquisitionError.recoveryRequired }
            if job != nil { return entries.map(Self.available) }
            return try await refresh().map(Self.available)
        } catch let error as InstallerAcquisitionError {
            if error == .recoveryRequired { blockedForRecovery = true }
            throw error
        } catch { throw .catalogUnavailable }
    }

    private func refresh() async throws -> [AppleInstallerProduct.Resolved] {
        guard !refreshing else { throw InstallerAcquisitionError.catalogUnavailable }
        refreshing = true
        defer { refreshing = false }
        let folder = try store.makePendingDirectory()
        do {
            entries = try await catalog.products(in: folder)
            return entries
        } catch AppleInstallerCatalog.Failure.recoveryRequired {
            blockedForRecovery = true
            throw InstallerAcquisitionError.recoveryRequired
        } catch AppleInstallerCatalog.Failure.cleanupFailed {
            blockedForRecovery = true
            throw InstallerAcquisitionError.recoveryRequired
        }
    }

    func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent> {
        let (stream, events) = AsyncStream.makeStream(of: InstallerAcquisitionEvent.self)
        guard job == nil else {
            events.yield(.failed(.alreadyDownloading))
            events.finish()
            return stream
        }
        guard !blockedForRecovery, (try? store.hasPendingWork()) == false else {
            blockedForRecovery = true
            events.yield(.failed(.recoveryRequired))
            events.finish()
            return stream
        }
        continuation = events
        events.onTermination = { [weak self] reason in
            if case .cancelled = reason { Task { await self?.cancelDownload() } }
        }
        job = Task { await perform(installer, events: events) }
        return stream
    }

    func cancelDownload() async {
        guard let job else { return }
        // Once publication wins, finish reporting that complete result rather than erase it.
        if !publishing { job.cancel() }
        await job.value
    }

    private func perform(
        _ selected: AvailableInstaller,
        events: AsyncStream<InstallerAcquisitionEvent>.Continuation
    ) async {
        var pending: URL?
        var prepared: PreparedInstallerPackage?
        var stage = InstallerAcquisitionStage.downloading
        var committed = false
        do {
            let products = try await refresh()
            guard let product = products.first(where: { Self.available($0) == selected }) else {
                finish(.blocked(.catalogChanged))
                return
            }
            let updates = installerService.updates()
            var iterator = updates.makeAsyncIterator()
            let locals = await iterator.next()
            try Task.checkCancellation()
            guard let locals else {
                finish(.blocked(.localStateUnavailable))
                return
            }
            switch InstallerAcquisitionPolicy.decision(
                for: selected, among: products.map(Self.available),
                localInstallers: locals, destinationOccupied: false)
            {
            case .use(let source):
                finish(.completed(source))
                return
            case .unavailable(let reason):
                finish(.blocked(reason))
                return
            case .download: break
            }
            let folder = try store.makePendingDirectory()
            pending = folder
            let package = folder.appending(path: "InstallAssistant.pkg")
            events.yield(.stage(.connecting))
            let transfer = InstallerDownload(
                origin: .package, destination: package,
                maximumBytes: product.product.size, expectedBytes: product.product.size
            ) { bytes, total, speed in
                events.yield(.transfer(InstallerTransferProgress(bytes: bytes, total: total, bytesPerSecond: speed)))
            }
            _ = try await transfer.start(product.product.packageURL)
            try Task.checkCancellation()
            stage = .verifying
            events.yield(.stage(stage))
            events.yield(.progress(nil))
            let output = try await InstallerCommand.verifyPackage(package).run(in: folder, timeout: 60)
            guard let text = String(data: output, encoding: .utf8),
                AppleInstallerPackageSignature.acceptsSuccessfulCheck(text)
            else { throw InstallerAcquisitionError.verificationFailed }
            try Task.checkCancellation()
            stage = .preparing
            events.yield(.stage(stage))
            let candidate = try await InstallerPackagePreparer.prepare(package)
            prepared = candidate
            let expected = try InstallerOSIdentity(version: product.version.description, build: product.build)
            let source = try await AcquiredInstallerReader.read(candidate, expected: expected)
            try Task.checkCancellation()
            publishing = true
            let retained = try await store.commit(candidate, identity: source)
            committed = true
            prepared = nil
            let registered = try await installerService.addRetained(retained)
            try FileManager.default.removeItem(at: folder)
            pending = nil
            finish(.completed(registered))
        } catch InstallerCommand.Failure.lostProcess {
            blockForRecovery()
        } catch InstallerPackagePreparer.PreparationError.recoveryRequired {
            blockForRecovery()
        } catch InstallerPackagePreparer.PreparationError.cleanupFailed {
            blockForRecovery()
        } catch InstallerSupportMetadata.Failure.recoveryRequired {
            blockForRecovery()
        } catch {
            logger.error(
                "Acquisition failed in \(stage.rawValue, privacy: .public): \(String(describing: error), privacy: .private)"
            )
            do {
                if let prepared { try FileManager.default.removeItem(at: prepared.temporaryDirectory) }
                if let pending { try FileManager.default.removeItem(at: pending) }
            } catch {
                blockForRecovery()
                return
            }
            if committed {
                blockForRecovery()
                return
            }
            if error is CancellationError || (error as? InstallerPackagePreparer.PreparationError) == .cancelled {
                finish(.cancelled)
            } else if let error = error as? InstallerAcquisitionError {
                finish(.failed(error))
            } else {
                finish(
                    .failed(
                        stage == .downloading
                            ? .downloadFailed : stage == .verifying ? .verificationFailed : .preparationFailed))
            }
        }
    }

    private func blockForRecovery() {
        blockedForRecovery = true
        finish(.failed(.recoveryRequired))
    }

    private func finish(_ event: InstallerAcquisitionEvent) {
        continuation?.yield(event)
        continuation?.finish()
        continuation = nil
        publishing = false
        job = nil
    }

    private static func available(_ product: AppleInstallerProduct.Resolved) -> AvailableInstaller {
        AvailableInstaller(
            title: InstallerMetadata.name(for: product.version), version: product.version,
            build: product.build, sizeInBytes: product.product.size)
    }
}
