//
//  HelperCreationServiceTests.swift
//  RelenteTests
//
//  The Debug creation that formats through the helper and pretends the rest, with a fake helper
//  client: nothing is erased.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Testing

@testable import Relente

@Suite(.timeLimit(.minutes(1)))
struct HelperCreationServiceTests {

    /// Answers like the helper, and remembers what it was asked.
    private actor FakeClient: HelperClient {
        let outcome: FormatOutcome?
        private(set) var formatted: [String] = []
        private(set) var authorizations: [Data] = []
        private(set) var cancels = 0

        init(outcome: FormatOutcome?) { self.outcome = outcome }

        func connectsToCurrentHelper() async -> Bool { true }

        func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? {
            formatted.append(drive.bsdName)
            authorizations.append(authorization)
            return outcome
        }

        func cancel() async { cancels += 1 }
    }

    private let installer = InstallerSource.samples[0]
    private let drive = Drive.samples[0]

    private func run(_ client: FakeClient, authorization: EraseAuthorization? = nil) async -> [CreationEvent] {
        let service = HelperCreationService(client: client, simulatedDuration: .milliseconds(50))
        var events: [CreationEvent] = []
        for await event in service.create(installer: installer, drive: drive, authorization: authorization) {
            events.append(event)
        }
        return events
    }

    @Test func `only the format is real`() {
        #expect(HelperCreationService(client: FakeClient(outcome: .formatted)).simulation == .afterFormat)
        #expect(HelperCreationService(client: FakeClient(outcome: .formatted)).erasesDrive)
    }

    @Test func `it formats the drive with the authorization, then pretends the rest`() async {
        let client = FakeClient(outcome: .formatted)
        let authorization = EraseAuthorization(reference: nil, externalForm: Data([1, 2, 3]))
        let events = await run(client, authorization: authorization)

        #expect(await client.formatted == [drive.bsdName])
        #expect(await client.authorizations == [Data([1, 2, 3])])
        // First Format with no percentage, then the simulated phases, then the end.
        guard case .progress(let first) = events.first else {
            Issue.record("The first event isn't progress")
            return
        }
        #expect(first.phase == .format)
        #expect(first.phaseFraction == nil)
        let phases = events.compactMap { event -> CreationPhase? in
            if case .progress(let progress) = event { return progress.phase }
            return nil
        }
        #expect(phases.dropFirst().allSatisfy { $0 != .format })
        #expect(phases.contains(.copy) && phases.contains(.makeBootable) && phases.contains(.verify))
        #expect(events.last == .finished)
    }

    @Test(arguments: [
        (FormatOutcome.driveChanged, CreationFailure.Reason.driveChanged),
        (.driveNotAllowed, .driveNotAllowed),
        (.invalidIdentifier, .driveNotAllowed),
        (.driveDisconnected, .driveDisconnected),
        (.formatFailed, .formatFailed),
        (.notAuthorized, .unknown),
        (.busy, .unknown),
    ])
    func `a refusal fails the run with its reason, during Format`(
        outcome: FormatOutcome, reason: CreationFailure.Reason
    )
        async
    {
        let events = await run(FakeClient(outcome: outcome))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == reason)
        #expect(failure.progress.phase == .format)
        #expect(events.count == 2)
    }

    @Test func `no answer from the helper means it didn't respond`() async {
        let events = await run(FakeClient(outcome: nil))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == .helperUnavailable)
    }

    @Test func `the simulated part skips Format`() {
        let timeline = SimulatedCreationService.timeline(for: installer, failure: nil)
        let rest = HelperCreationService.afterFormat(timeline)
        #expect(rest.last == .finished)
        #expect(!rest.contains { if case .progress(let p) = $0 { p.phase == .format } else { false } })
        #expect(rest.count < timeline.count)
    }
}
