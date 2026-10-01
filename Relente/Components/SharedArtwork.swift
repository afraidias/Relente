//
//  SharedArtwork.swift
//  Relente
//
//  Artwork that travels between the assistant's screens: the chosen drive, the installer's
//  icon and the footer's step indicator. Each screen marks where it goes; inside the assistant
//  the mark is left empty (keeping its space) and `AssistantView` draws the artwork there,
//  moving it from one screen's mark to the next. Outside the assistant (previews) the screens
//  draw it themselves.
//
//  `matchedGeometryEffect` isn't used: when screens slide, the slide's offset adds to the flight
//  and the artwork starts outside the window.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

nonisolated enum SharedArtwork: Hashable, Sendable {
    case drive
    case installer
    case stepIndicator
}

/// Where each screen wants each piece of artwork.
nonisolated struct SharedArtworkAnchors: PreferenceKey {
    static let defaultValue: [AssistantStep: [SharedArtwork: Anchor<CGRect>]] = [:]

    static func reduce(
        value: inout [AssistantStep: [SharedArtwork: Anchor<CGRect>]],
        nextValue: () -> [AssistantStep: [SharedArtwork: Anchor<CGRect>]]
    ) {
        value.merge(nextValue()) { current, next in current.merging(next) { $1 } }
    }
}

extension EnvironmentValues {
    /// The assistant screen a view belongs to, or `nil` outside the assistant.
    @Entry var assistantScreen: AssistantStep?
}

extension View {
    /// Marks this view as the place of `artwork` on its screen. Inactive marks (e.g. a drive that
    /// isn't selected) draw the view as usual.
    func sharedArtwork(_ artwork: SharedArtwork, isActive: Bool = true) -> some View {
        modifier(SharedArtworkMark(artwork: artwork, isActive: isActive))
    }
}

private struct SharedArtworkMark: ViewModifier {
    let artwork: SharedArtwork
    let isActive: Bool

    @Environment(\.assistantScreen) private var screen

    func body(content: Content) -> some View {
        if let screen, isActive {
            content
                .hidden()
                .anchorPreference(key: SharedArtworkAnchors.self, value: .bounds) { [screen: [artwork: $0]] }
        } else {
            content
        }
    }
}
