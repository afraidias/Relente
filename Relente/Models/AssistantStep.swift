//
//  AssistantStep.swift
//  Relente
//
//  The assistant's screens, and how a change from one to another is animated.
//  Spec: specs/006-assistant-navigation/spec.md
//

import Foundation

/// One screen of the assistant. Error is the `creating` step with a failed creation (spec 004).
nonisolated enum AssistantStep: Hashable, Sendable {
    case installer
    case drive
    case review
    case creating
    case done

    /// Number of steps the footer counts. Creating and Done share the last one.
    static let stepCount = 4

    /// The step number in the footer, starting at 1.
    var stepNumber: Int {
        switch self {
        case .installer: 1
        case .drive: 2
        case .review: 3
        case .creating, .done: 4
        }
    }

    /// The step name in the footer: a noun (docs/product.md).
    var stepName: LocalizedStringResource {
        switch self {
        case .installer:
            LocalizedStringResource(
                "Installer", comment: "Name of the first assistant step, where the macOS installer is chosen.")
        case .drive:
            LocalizedStringResource(
                "USB Drive", comment: "Name of the second assistant step, where the USB drive or SD card is chosen.")
        case .review:
            LocalizedStringResource(
                "Review", comment: "Name of the third assistant step, where the user reviews and confirms the erase.")
        case .creating:
            LocalizedStringResource(
                "Creation", comment: "Name of the fourth assistant step, where the installer is being made.")
        case .done:
            LocalizedStringResource(
                "Done", comment: "Name of the assistant's last screen, once the installer is ready.")
        }
    }
}

/// How the last screen change moves: the Flow table of the spec.
nonisolated struct ScreenChange: Hashable, Sendable {
    enum Direction: Hashable, Sendable {
        case forward
        case back
    }

    enum Style: Hashable, Sendable {
        /// The new screen comes in from the side it's heading to.
        case slide
        /// The screens fade into each other: endings and restarts, not steps.
        case crossfade
    }

    let direction: Direction
    let style: Style
}
