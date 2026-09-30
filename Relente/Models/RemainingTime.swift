//
//  RemainingTime.swift
//  Relente
//
//  The REMAINING figure on the Creating screen: an estimate of the time left in the
//  current phase, or why there isn't one.
//  Spec: specs/004-creating-screen/spec.md
//

import Foundation

nonisolated enum RemainingTime: Hashable, Sendable {
    /// There's nothing to estimate from yet (no speed, or the phase is at 0 %).
    case calculating
    /// Estimated time left in the current phase.
    case estimate(Duration)
    /// A phase after Copy that reports no percentage.
    case almostDone

    /// Text shown under REMAINING, e.g. "About 4 min".
    var text: LocalizedStringResource {
        switch self {
        case .calculating:
            return LocalizedStringResource(
                "Calculating…", comment: "Creating screen, REMAINING: not enough data yet to estimate the time left.")
        case .almostDone:
            return LocalizedStringResource(
                "Almost done", comment: "Creating screen, REMAINING: a last phase that doesn't report its progress.")
        case .estimate(let duration) where duration < .seconds(60):
            return LocalizedStringResource(
                "Less than a minute", comment: "Creating screen, REMAINING: under 60 seconds left.")
        case .estimate(let duration):
            let minutes = (Double(duration.components.seconds) / 60).rounded()
            let rounded = Duration.seconds(Int64(minutes) * 60)
            return LocalizedStringResource(
                "About \(rounded, format: .units(allowed: [.hours, .minutes], width: .abbreviated))",
                comment:
                    "Creating screen, REMAINING: estimated time left. The value is a duration, e.g. 4 min or 1 hr, 20 min."
            )
        }
    }
}
