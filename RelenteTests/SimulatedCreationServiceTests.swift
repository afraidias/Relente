//
//  SimulatedCreationServiceTests.swift
//  RelenteTests
//
//  The Debug-only simulation that stands in for `createinstallmedia` until roadmap step 7.
//  Spec: specs/006-assistant-navigation/spec.md
//

#if DEBUG
    import Testing

    @testable import Relente

    struct SimulatedCreationServiceTests {

        private let installer = InstallerSource.samples[0]

        private func progresses(_ events: [CreationEvent]) -> [CreationProgress] {
            events.compactMap {
                if case .progress(let progress) = $0 { progress } else { nil }
            }
        }

        // MARK: - Timeline

        @Test func `goes through the four phases in order and finishes`() {
            let events = SimulatedCreationService.timeline(for: installer, failure: nil)
            var phases: [CreationPhase] = []
            for progress in progresses(events) where phases.last != progress.phase {
                phases.append(progress.phase)
            }
            #expect(phases == CreationPhase.allCases)
            #expect(events.last == .finished)
        }

        @Test func `overall progress never goes backwards and ends at 100 %`() {
            let fractions = progresses(SimulatedCreationService.timeline(for: installer, failure: nil))
                .map(\.overallFraction)
            #expect(zip(fractions, fractions.dropFirst()).allSatisfy { $0 <= $1 })
            #expect(fractions.last == 1)
        }

        @Test func `copied bytes never exceed the installer's size`() {
            let all = progresses(SimulatedCreationService.timeline(for: installer, failure: nil))
            #expect(all.allSatisfy { $0.copiedBytes <= installer.size })
            #expect(all.allSatisfy { $0.installerSize == installer.size })
        }

        @Test func `the drive disconnected failure stops during copy`() throws {
            let events = SimulatedCreationService.timeline(for: installer, failure: .driveDisconnected)
            guard case .failed(let failure) = try #require(events.last) else {
                Issue.record("The last event isn't a failure")
                return
            }
            #expect(failure.reason == .driveDisconnected)
            #expect(failure.progress.phase == .copy)
            #expect(failure.progress == progresses(events).last)
            #expect(!events.contains(.finished))
        }

        // MARK: - Speed

        @Test func `the normal run lasts about 15 s and the fast one about 2 s`() {
            #expect(SimulatedCreationService.Speed.normal.duration == .seconds(15))
            #expect(SimulatedCreationService.Speed.fast.duration == .seconds(2))
        }

        @Test func `reading the launch arguments`() {
            #expect(SimulatedCreationService.Speed(launchArgument: "fast") == .fast)
            #expect(SimulatedCreationService.Speed(launchArgument: nil) == .normal)
            #expect(SimulatedCreationService.Speed(launchArgument: "warp") == .normal)
            #expect(SimulatedCreationService.failure(launchArgument: "driveDisconnected") == .driveDisconnected)
            #expect(SimulatedCreationService.failure(launchArgument: nil) == nil)
            #expect(SimulatedCreationService.failure(launchArgument: "cancelled") == nil)
        }

        // MARK: - Stream

        @Test func `the stream delivers the whole timeline`() async {
            let service = SimulatedCreationService(speed: .fast, failure: nil)
            var received: [CreationEvent] = []
            for await event in service.create(installer: installer, drive: Drive.samples[0]) {
                received.append(event)
            }
            #expect(received == SimulatedCreationService.timeline(for: installer, failure: nil))
            #expect(service.isSimulated)
        }
    }
#endif
