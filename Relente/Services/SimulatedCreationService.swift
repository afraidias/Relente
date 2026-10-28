//
//  SimulatedCreationService.swift
//  Relente
//
//  Debug builds only: pretends to make the installer, so the whole assistant can be walked and
//  tested without touching a disk or talking to the helper. Its sample output exercises Details.
//  Spec: specs/006-assistant-navigation/spec.md
//

#if DEBUG
    import Foundation

    nonisolated struct SimulatedCreationService: CreationService {

        enum Speed: Hashable, Sendable {
            /// About 15 s, to watch the screens.
            case normal
            /// About 2 s, for UI tests (`-simulationSpeed fast`).
            case fast
            /// Long enough to exercise accessibility and secondary windows in UI tests.
            case slow

            var duration: Duration {
                switch self {
                case .normal: .seconds(15)
                case .fast: .seconds(2)
                case .slow: .seconds(60)
                }
            }

            init(launchArgument: String?) {
                switch launchArgument {
                case "fast": self = .fast
                case "slow": self = .slow
                default: self = .normal
                }
            }
        }

        let speed: Speed
        /// Why it fails partway through Copy, or `nil` to finish.
        let failure: CreationFailure.Reason?
        var simulatesLiveFeedback = false
        var simulatesMeasuredCopy = false

        var simulation: CreationSimulation? { .everything }

        /// The failure to simulate from `-simulateFailure`; cancellation uses the Cancel button.
        static func failure(launchArgument: String?) -> CreationFailure.Reason? {
            switch launchArgument {
            case "driveDisconnected": .driveDisconnected
            case "volumeAccessDenied": .volumeAccessDenied
            default: nil
            }
        }

        func create(installer: InstallerSource, drive: Drive, authorization: EraseAuthorization?)
            -> AsyncStream<CreationEvent>
        {
            Self.play(
                Self.timeline(
                    for: installer, failure: failure, liveFeedback: simulatesLiveFeedback,
                    measuredCopy: simulatesMeasuredCopy),
                over: speed.duration)
        }

        /// Sends the events one after another, spread over `duration`. Cancelling the task that
        /// reads the stream stops it.
        static func play(_ events: [CreationEvent], over duration: Duration) -> AsyncStream<CreationEvent> {
            let interval = duration / max(events.count, 1)
            return AsyncStream { continuation in
                let task = Task {
                    for event in events {
                        try? await Task.sleep(for: interval)
                        if Task.isCancelled { break }
                        continuation.yield(event)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        // MARK: - Timeline

        /// Pretended copy speed, so simulated copied bytes and remaining time are believable.
        private static let bytesPerSecond: Int64 = 40_000_000

        /// Snapshots per phase, and how long each phase pretends to take.
        private static let plan: [(phase: CreationPhase, snapshots: Int, pretended: Duration)] = [
            (.format, 10, .seconds(10)),
            (.copy, 110, .zero),  // Copy's time comes from the size and the speed.
            (.makeBootable, 15, .seconds(30)),
            (.verify, 15, .seconds(20)),
        ]

        /// Every event of a simulated run, in order.
        static func timeline(
            for installer: InstallerSource, failure: CreationFailure.Reason?, liveFeedback: Bool = false,
            measuredCopy: Bool = false
        ) -> [CreationEvent] {
            let copyTime = Duration.seconds(Double(installer.size) / Double(bytesPerSecond))
            var events: [CreationEvent] = []
            events.append(
                .output(CreationOutputLine(timestamp: Date(timeIntervalSince1970: 0), text: "Erasing disk: 0%...")))
            for (phase, snapshots, pretended) in plan {
                let phaseTime = phase == .copy ? copyTime : pretended
                for index in 1...snapshots {
                    let fraction = Double(index) / Double(snapshots)
                    let isCopy = phase == .copy
                    let progress = CreationProgress(
                        phase: phase,
                        // Live Copy models Apple's "Copying essential files..." state, which
                        // provides no phase percentage or reliable installer byte count.
                        phaseFraction: phase == .makeBootable || (liveFeedback && isCopy && !measuredCopy)
                            ? nil : fraction,
                        phaseElapsed: phaseTime * fraction,
                        copiedBytes: isCopy
                            ? (liveFeedback && !measuredCopy ? 0 : Int64(Double(installer.size) * fraction))
                            : (phase == .format ? 0 : installer.size),
                        installerSize: installer.size,
                        // Only the sample path may provide this deterministic measurement.
                        bytesPerSecond: isCopy && (!liveFeedback || measuredCopy) && index > 3
                            ? bytesPerSecond : 0,
                        isLive: liveFeedback,
                        hasMeasuredCopyProgress: isCopy && measuredCopy
                    )
                    events.append(.progress(progress))
                    if let failure, isCopy, index == snapshots * 2 / 5 {
                        events.append(.failed(CreationFailure(reason: failure, progress: progress)))
                        return events
                    }
                }
            }
            events.append(.finished)
            return events
        }
    }
#endif
