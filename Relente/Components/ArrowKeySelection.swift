//
//  ArrowKeySelection.swift
//  Relente
//
//  Left and right arrows move the selection in a row of options (installers, drives) as soon
//  as the screen appears. In right-to-left languages the arrows follow the row's direction.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

extension View {
    /// Calls `move` with -1 for the previous option and +1 for the next one.
    func selectsWithArrowKeys(_ move: @escaping (Int) -> Void) -> some View {
        modifier(ArrowKeySelection(move: move))
    }
}

private struct ArrowKeySelection: ViewModifier {
    let move: (Int) -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            // The selection already shows where the arrows act.
            .focusEffectDisabled()
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onMoveCommand { direction in
                let forward = layoutDirection == .leftToRight ? MoveCommandDirection.right : .left
                let backward = layoutDirection == .leftToRight ? MoveCommandDirection.left : .right
                switch direction {
                case forward: move(1)
                case backward: move(-1)
                default: break
                }
            }
    }
}
