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

    /// Whether `step`'s screen has a place for this artwork.
    func isMarked(on step: AssistantStep) -> Bool {
        switch self {
        case .installer, .stepIndicator: true
        case .drive: step != .installer
        }
    }

    /// The artwork that doesn't fly from `old` to `new`: the screens draw it, so it comes or goes
    /// with them, exactly in step. That's artwork one of the two screens has no place for, and
    /// everything when starting over from Creating (Error) or Done, which crossfades as a restart.
    static func stayingWithScreens(from old: AssistantStep, to new: AssistantStep) -> Set<SharedArtwork> {
        if new == .installer, old == .creating || old == .done { return [.drive, .installer] }
        return Set([.drive, .installer].filter { !$0.isMarked(on: old) || !$0.isMarked(on: new) })
    }
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
    /// Whether the assistant is moving from one screen to another.
    @Entry var isChangingScreen = false
    /// Inside a scroll view (the grid of many installers or drives), a mark hands its artwork to
    /// the assistant only while the screen changes, so it can fly; at rest the view draws it
    /// itself, so it scrolls, fades and is clipped with the rest.
    @Entry var marksArtworkOnlyWhileChangingScreen = false
    /// While the screen changes, the artwork that stays with its screen instead of flying
    /// (`SharedArtwork.stayingWithScreens(from:to:)`): its marks draw it themselves.
    @Entry var artworkStayingWithScreen: Set<SharedArtwork> = []
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
    @Environment(\.isChangingScreen) private var isChangingScreen
    @Environment(\.marksArtworkOnlyWhileChangingScreen) private var onlyWhileChangingScreen
    @Environment(\.artworkStayingWithScreen) private var stayingWithScreen

    /// Whether the assistant draws the artwork here instead of this view.
    private var handsOver: Bool {
        guard isActive, !stayingWithScreen.contains(artwork) else { return false }
        return !onlyWhileChangingScreen || isChangingScreen
    }

    func body(content: Content) -> some View {
        if let screen, handsOver {
            content
                .hidden()
                .anchorPreference(key: SharedArtworkAnchors.self, value: .bounds) { [screen: [artwork: $0]] }
        } else {
            content
        }
    }
}
