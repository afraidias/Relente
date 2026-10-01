//
//  RollingFigure.swift
//  Relente
//
//  Figures that change while the user watches (the Creating screen's percentage, COPIED, SPEED,
//  REMAINING) roll like a counter: digits roll up when the figure grows and down when it
//  shrinks. With Reduce Motion they just change.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

extension View {
    /// Rolls the digits of this text when `value` changes; `value` gives the direction.
    func rollingFigure(_ value: Double) -> some View {
        modifier(RollingFigure(value: value))
    }
}

private struct RollingFigure: ViewModifier {
    let value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText(value: value))
            .animation(reduceMotion ? nil : .snappy, value: value)
    }
}

#Preview {
    @Previewable @State var percent = 42

    VStack(spacing: 16) {
        Text(percent, format: .percent)
            .font(Theme.Fonts.figure)
            .rollingFigure(Double(percent))
        HStack {
            Button("−") { percent -= 7 }
            Button("+") { percent += 7 }
        }
    }
    .padding()
}
