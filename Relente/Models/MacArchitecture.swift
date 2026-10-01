//
//  MacArchitecture.swift
//  Relente
//
//  The two kinds of Mac, which start up from an external drive with different keys,
//  and which one this Mac is.
//  Spec: specs/005-done-screen/spec.md
//

import Foundation

nonisolated enum MacArchitecture: Hashable, Sendable, CaseIterable {
    case appleSilicon
    case intel

    // MARK: - Detection

    /// This Mac, read once from the hardware.
    static let current = MacArchitecture(arm64Flag: readArm64Flag())

    /// The architecture for the value of `hw.optional.arm64`: 1 on Apple silicon (also when the
    /// app runs under Rosetta, so an Apple silicon Mac is never taken for Intel), 0 or missing
    /// on Intel.
    init(arm64Flag: Int32?) {
        self = arm64Flag == 1 ? .appleSilicon : .intel
    }

    /// `hw.optional.arm64`, or `nil` when the key doesn't exist (older Intel Macs).
    private static func readArm64Flag() -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    // MARK: - Start-up card

    /// Heading of the card, e.g. "Apple silicon".
    var name: LocalizedStringResource {
        switch self {
        case .appleSilicon:
            LocalizedStringResource("Apple silicon", comment: "Done screen card heading: Macs with Apple silicon.")
        case .intel:
            LocalizedStringResource("Intel", comment: "Done screen card heading: Macs with an Intel processor.")
        }
    }

    /// Capsule next to the heading: when to press the key.
    var whenToPress: LocalizedStringResource {
        switch self {
        case .appleSilicon:
            LocalizedStringResource(
                "HOLD", comment: "Done screen card capsule, uppercase: keep the power button pressed.")
        case .intel:
            LocalizedStringResource(
                "AT START-UP", comment: "Done screen card capsule, uppercase: press the key while the Mac turns on.")
        }
    }

    /// What to do on this kind of Mac, ending with the name of the drive to choose.
    func startUpText(volumeName: String) -> LocalizedStringResource {
        switch self {
        case .appleSilicon:
            LocalizedStringResource(
                "Hold the power button until you see the start-up options, then choose “\(volumeName)”.",
                comment:
                    "Done screen card for Apple silicon Macs. The value is the drive's name, e.g. Install macOS Tahoe."
            )
        case .intel:
            LocalizedStringResource(
                "Hold Option (⌥) right after turning on the Mac, then choose “\(volumeName)”.",
                comment: "Done screen card for Intel Macs. The value is the drive's name, e.g. Install macOS Tahoe."
            )
        }
    }
}
