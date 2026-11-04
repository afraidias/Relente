import Foundation
import Testing

@testable import Relente

@MainActor
struct AssistantAcquisitionTests {
    private actor FailedCatalogAcquisition: InstallerAcquisitionService {
        private(set) var requestCount = 0

        func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller] {
            requestCount += 1
            throw .recoveryRequired
        }

        func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent> {
            AsyncStream { $0.finish() }
        }

        func cancelDownload() async {}
    }

    private actor ControlledAcquisition: InstallerAcquisitionService {
        let installer = AvailableInstaller(title: "macOS Ventura", version: "13.7.8", build: "22H730")
        private var events: AsyncStream<InstallerAcquisitionEvent>.Continuation?
        private var cancellationStarted: CheckedContinuation<Void, Never>?
        private var release: CheckedContinuation<Void, Never>?
        private var requested = false

        func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller] { [installer] }
        func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent> {
            let (stream, continuation) = AsyncStream.makeStream(of: InstallerAcquisitionEvent.self)
            events = continuation
            continuation.yield(.stage(.preparing))
            return stream
        }
        func cancelDownload() async {
            await withCheckedContinuation { continuation in
                release = continuation
                requested = true
                cancellationStarted?.resume()
                cancellationStarted = nil
            }
            events?.yield(.cancelled)
            events?.finish()
        }
        func waitForCancellation() async {
            if requested { return }
            await withCheckedContinuation { cancellationStarted = $0 }
        }
        func confirmStoppedAndCleaned() {
            release?.resume()
            release = nil
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func quitWaitsForPreparationTerminationAndStreamCompletion() async throws {
        let service = ControlledAcquisition()
        let model = Assistant(installers: [], drives: [], acquisitionService: service)
        model.showDownload()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.availableInstallers.isEmpty && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let installer = try #require(model.availableInstallers.first)
        model.downloadAvailableInstaller(installer)
        let quit = Task { await model.prepareForTermination() }
        await service.waitForCancellation()
        #expect(model.isDownloadingInstaller)
        #expect(model.isCancellingInstallerDownload)
        #expect(!model.isShowingDownloadCancelled)
        await service.confirmStoppedAndCleaned()
        #expect(await quit.value)
        #expect(!model.isDownloadingInstaller)
        #expect(model.isShowingDownloadCancelled)
        #expect(model.selectedInstallerID == nil)
        #expect(model.downloadCompletionID == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func completionSignalOnlyFollowsAnActualAcquisition() async throws {
        let service = SampleInstallerAcquisitionService(downloadDelay: .milliseconds(10))
        let model = Assistant(installers: [], drives: [], acquisitionService: service)
        model.showDownload()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.availableInstallers.isEmpty && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let installer = try #require(model.availableInstallers.first)
        model.downloadAvailableInstaller(installer)
        while model.isDownloadingInstaller && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isDownloadingInstaller)
        #expect(model.downloadCompletionID != nil)
        #expect(!model.isShowingDownloadCancelled)
    }

    @Test(.timeLimit(.minutes(1)))
    func catalogRecoveryFailureNotifiesAndCanBeRetried() async throws {
        let service = FailedCatalogAcquisition()
        let model = Assistant(installers: [], drives: [], acquisitionService: service)
        model.showDownload()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.catalogErrorNotificationID == nil && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let firstNotification = try #require(model.catalogErrorNotificationID)
        #expect(model.acquisitionError == .recoveryRequired)
        #expect(await service.requestCount == 1)

        model.retryAvailableInstallers()
        while model.catalogErrorNotificationID == firstNotification && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.catalogErrorNotificationID != firstNotification)
        #expect(await service.requestCount == 2)
    }
}
