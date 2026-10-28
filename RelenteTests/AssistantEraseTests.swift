//
//  AssistantEraseTests.swift
//  RelenteTests
//
//  "Erase and Create" with a creation that erases the drive: the helper must be ready, macOS asks
//  for authorization first, and the drive is followed by its BSD name once the format renames it.
//  Sample services only: nothing is authorized, formatted or erased.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Testing
import os

@testable import Relente

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AssistantEraseTests {

    /// A creation whose events the test sends, and which remembers how it was started.
    nonisolated private final class ControlledCreationService: CreationService {
        let simulation: CreationSimulation?
        private let state = OSAllocatedUnfairLock<
            (continuation: AsyncStream<CreationEvent>.Continuation?, authorization: EraseAuthorization?, starts: Int)
        >(initialState: (nil, nil, 0))

        init(simulation: CreationSimulation?) {
            self.simulation = simulation
        }

        func create(installer: InstallerSource, drive: Drive, authorization: EraseAuthorization?)
            -> AsyncStream<CreationEvent>
        {
            let (stream, continuation) = AsyncStream.makeStream(of: CreationEvent.self)
            state.withLock { $0 = (continuation, authorization, $0.starts + 1) }
            return stream
        }

        func send(_ event: CreationEvent) {
            state.withLock { $0.continuation }?.yield(event)
        }

        func finish() {
            state.withLock { $0.continuation }?.finish()
        }

        var starts: Int { state.withLock { $0.starts } }
        var authorization: EraseAuthorization? { state.withLock { $0.authorization } }
    }

    private let installer = InstallerSource.samples[0]
    /// 64 GB, fits the sample installer.
    private let stick = Drive(
        id: "UUID-OLD", bsdName: "disk4", name: "Stick", model: "Stick", kind: .usbDrive, capacity: 64_000_000_000,
        volumeURL: URL(filePath: "/Volumes/Stick"), usedSpace: .bytes(0))
    /// The same drive after the format: same BSD name, new media UUID.
    private let formatted = Drive(
        id: "UUID-NEW", bsdName: "disk4", name: "MyVolume", model: "Stick", kind: .usbDrive,
        capacity: 64_000_000_000, usedSpace: .bytes(0))

    private func makeAssistant(
        service: ControlledCreationService, authorizer: SampleEraseAuthorizer = SampleEraseAuthorizer(),
        helperClient: any HelperClient = SampleHelperClient()
    ) -> Assistant {
        let assistant = Assistant(
            installers: [installer], drives: [stick], helperService: SampleHelperService(status: .ready),
            helperClient: helperClient, authorizer: authorizer, creationService: service)
        assistant.continueToDrive()
        assistant.screenChangeDidEnd()
        assistant.selectDrive(stick.id)
        assistant.continueToReview()
        assistant.screenChangeDidEnd()
        assistant.hasConfirmed = true
        return assistant
    }

    /// Lets the creation task read the events sent.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    // MARK: - Before erasing

    @Test func `an unexpected end of the creation stream reports failure`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service)
        await assistant.eraseAndCreate()
        await waitUntil { service.starts == 1 }
        service.finish()
        await waitUntil {
            if case .failed = assistant.creation { return true }
            return false
        }
        guard case .failed(let failure) = assistant.creation else {
            Issue.record("The creation remained running")
            return
        }
        #expect(failure.reason == .helperUnavailable)
    }

    @Test func `with the helper off, the alert is shown and nothing starts`() async throws {
        let service = ControlledCreationService(simulation: .afterFormat)
        let helper = SampleHelperService(status: .ready)
        let assistant = Assistant(
            installers: [installer], drives: [stick], helperService: helper, creationService: service)
        assistant.continueToDrive()
        assistant.screenChangeDidEnd()
        assistant.selectDrive(stick.id)
        assistant.continueToReview()
        assistant.screenChangeDidEnd()
        assistant.hasConfirmed = true
        // Turned off in System Settings, before the next check noticed it.
        try await helper.unregister()

        await assistant.eraseAndCreate()
        #expect(assistant.isShowingHelperOffAlert)
        #expect(assistant.step == .review)
        #expect(service.starts == 0)

        assistant.openHelperSettingsFromAlert()
        #expect(!assistant.isShowingHelperOffAlert)
    }

    @Test func `a helper that fails the version check leaves Review recoverable`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service, helperClient: SampleHelperClient(isCurrent: false))

        await assistant.eraseAndCreate()

        #expect(assistant.isShowingHelperOffAlert)
        #expect(assistant.step == .review)
        #expect(assistant.hasConfirmed)
        #expect(service.starts == 0)
    }

    @Test func `cancelling the authorization leaves Review as it was`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service, authorizer: SampleEraseAuthorizer(error: .cancelled))

        await assistant.eraseAndCreate()
        #expect(assistant.step == .review)
        #expect(assistant.hasConfirmed)
        #expect(!assistant.isAuthorizing)
        #expect(service.starts == 0)
    }

    @Test func `a denied authorization starts nothing either`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service, authorizer: SampleEraseAuthorizer(error: .denied))
        await assistant.eraseAndCreate()
        #expect(assistant.step == .review)
        #expect(service.starts == 0)
    }

    @Test func `a denied helper write check keeps Review and never creates`() async {
        let service = ControlledCreationService(simulation: nil)
        let assistant = makeAssistant(
            service: service, helperClient: SampleHelperClient(writeAccessOutcome: .volumeAccessDenied))

        await assistant.eraseAndCreate()

        #expect(assistant.step == .review)
        #expect(assistant.isShowingDiskAccessAlert)
        #expect(!assistant.isAuthorizing)
        #expect(service.starts == 0)
    }

    @Test func `once authorized, the creation starts with the authorization`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service)

        await assistant.eraseAndCreate()
        await waitUntil { service.starts == 1 }
        #expect(assistant.step == .creating)
        #expect(service.starts == 1)
        #expect(service.authorization != nil)
    }

    @Test func `live creation starts with installer preparation before the USB phase`() async {
        let service = ControlledCreationService(simulation: nil)
        let assistant = makeAssistant(service: service)

        await assistant.eraseAndCreate()

        #expect(assistant.step == .creating)
        #expect(assistant.creation?.progress.isPreparingInstaller == true)
        #expect(assistant.creation?.progress.phase == .format)
    }

    @Test func `a full simulation asks for nothing`() async {
        let service = ControlledCreationService(simulation: .everything)
        // An authorizer that would refuse: it must not be asked.
        let assistant = makeAssistant(service: service, authorizer: SampleEraseAuthorizer(error: .cancelled))

        await assistant.eraseAndCreate()
        #expect(assistant.step == .creating)
        #expect(service.authorization == nil)
    }

    // MARK: - While erasing

    @Test func `the format's new identity isn't taken for a disconnection`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service)
        await assistant.eraseAndCreate()
        await waitUntil { service.starts == 1 }
        assistant.screenChangeDidEnd()

        assistant.updateDrives([formatted])
        #expect(assistant.creation?.failure == nil)
        #expect(assistant.creationDrive?.id == formatted.id)

        service.send(.finished)
        await waitUntil { assistant.step == .done }
        #expect(assistant.result?.drive.id == formatted.id)
    }

    @Test func `while the helper formats, a vanishing drive doesn't fail the run`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service)
        await assistant.eraseAndCreate()
        await waitUntil { service.starts == 1 }
        assistant.screenChangeDidEnd()

        assistant.updateDrives([])
        #expect(assistant.creation?.failure == nil)
    }

    @Test func `after the format, unplugging fails the run`() async {
        let service = ControlledCreationService(simulation: .afterFormat)
        let assistant = makeAssistant(service: service)
        await assistant.eraseAndCreate()
        await waitUntil { service.starts == 1 }
        assistant.screenChangeDidEnd()
        service.send(.progress(CreationProgress(phase: .copy, phaseFraction: 0.2, installerSize: installer.size)))
        await waitUntil { assistant.creation?.progress.phase == .copy }

        assistant.updateDrives([])
        #expect(assistant.creation?.failure?.reason == .driveDisconnected)
    }
}
