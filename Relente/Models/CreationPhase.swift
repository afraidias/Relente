//
//  CreationPhase.swift
//  Relente
//
//  The steps of making the bootable installer, in the order the phase bar shows them.
//  Spec: specs/004-creating-screen/spec.md
//

import Foundation

nonisolated enum CreationPhase: CaseIterable, Hashable, Sendable {
    // The case order is the bar order. The real order of `createinstallmedia` is checked in
    // roadmap step 7; reorder the cases if it differs.
    case format
    case copy
    case makeBootable
    case verify

    /// Share of the overall progress this phase stands for, in percentage points.
    /// Whole numbers, so the phases add up to exactly 100.
    var weight: Int {
        switch self {
        case .format: 5
        case .copy: 85
        case .makeBootable: 5
        case .verify: 5
        }
    }

    /// Name shown under the phase bar.
    var name: LocalizedStringResource {
        switch self {
        case .format:
            LocalizedStringResource("Format", comment: "Creation phase: erasing and formatting the drive.")
        case .copy:
            LocalizedStringResource("Copy", comment: "Creation phase: copying the installer to the drive.")
        case .makeBootable:
            LocalizedStringResource("Make bootable", comment: "Creation phase: making the drive able to start a Mac.")
        case .verify:
            LocalizedStringResource("Verify", comment: "Creation phase: checking the finished drive.")
        }
    }
}
