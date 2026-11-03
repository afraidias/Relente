//
//  PointingCursor.swift
//  Relente
//

import AppKit
import SwiftUI

private struct PointingCursor: ViewModifier {
    let isInteractive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                updateCursor()
            }
            .onChange(of: isEnabled) { if isHovering { updateCursor() } }
            .onChange(of: isInteractive) { if isHovering { updateCursor() } }
            .onDisappear { if isHovering { NSCursor.arrow.set() } }
    }

    private func updateCursor() {
        if isHovering && isEnabled && isInteractive { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
    }
}

extension View {
    func pointingCursor(_ isInteractive: Bool = true) -> some View {
        modifier(PointingCursor(isInteractive: isInteractive))
    }
}
