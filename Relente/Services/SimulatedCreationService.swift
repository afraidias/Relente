//
//  SimulatedCreationService.swift
//  Relente
//
//  Debug builds only: pretends to make the installer, so the whole assistant can be walked and
//  tested before `createinstallmedia` exists (roadmap step 7). It touches no disk and never
//  talks to the helper; the screens show that it's a simulation.
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

            var duration: Duration {
                switch self {
                case .normal: .seconds(15)
                case .fast: .seconds(2)
                }
            }

            init(launchArgument: String?) {
                self = launchArgument == "fast" ? .fast : .normal
            }
        }

        let speed: Speed
        /// Why it fails partway through Copy, or `nil` to finish.
        let failure: CreationFailure.Reason?

        var isSimulated: Bool { true }

        /// The failure to simulate from `-simulateFailure`. Only a drive being unplugged can be
        /// simulated; cancelling is done with the Cancel button.
        static func failure(launchArgument: String?) -> CreationFailure.Reason? {
            launchArgument == "driveDisconnected" ? .driveDisconnected : nil
        }

        func create(installer: InstallerSource, drive: Drive) -> AsyncStream<CreationEvent> {
            let events = Self.timeline(for: installer, failure: failure)
            let interval = speed.duration / events.count
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

        /// Pretended copy speed, so SPEED and REMAINING show believable figures: 40 MB/s.
        private static let bytesPerSecond: Int64 = 40_000_000

        /// Snapshots per phase, and how long each phase pretends to take.
        private static let plan: [(phase: CreationPhase, snapshots: Int, pretended: Duration)] = [
            (.format, 10, .seconds(10)),
            (.copy, 110, .zero),  // Copy's time comes from the size and the speed.
            (.makeBootable, 15, .seconds(30)),
            (.verify, 15, .seconds(20)),
        ]

        /// Every event of a simulated run, in order.
        static func timeline(for installer: InstallerSource, failure: CreationFailure.Reason?) -> [CreationEvent] {
            let copyTime = Duration.seconds(Double(installer.size) / Double(bytesPerSecond))
            var events: [CreationEvent] = []
            for (phase, snapshots, pretended) in plan {
                let phaseTime = phase == .copy ? copyTime : pretended
                for index in 1...snapshots {
                    let fraction = Double(index) / Double(snapshots)
                    let isCopy = phase == .copy
                    let progress = CreationProgress(
                        phase: phase,
                        // Make bootable reports no percentage, as spec 004 allows.
                        phaseFraction: phase == .makeBootable ? nil : fraction,
                        phaseElapsed: phaseTime * fraction,
                        copiedBytes: isCopy
                            ? Int64(Double(installer.size) * fraction) : (phase == .format ? 0 : installer.size),
                        installerSize: installer.size,
                        // Unknown for the first moments of Copy, as in a real run.
                        bytesPerSecond: isCopy && index > 3 ? bytesPerSecond : 0
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
