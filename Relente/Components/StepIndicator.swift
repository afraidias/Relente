//
//  StepIndicator.swift
//  Relente
//
//  Shows where the user is in the assistant: one dot per step
//  plus a label like "Step 1 of 4 · Installer".
//

import SwiftUI

struct StepIndicator: View {
    /// Current step, starting at 1.
    let current: Int
    let total: Int
    let name: LocalizedStringResource

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(1...total, id: \.self) { step in
                    Capsule()
                        .fill(color(of: step))
                        // The current step is a wider pill.
                        .frame(width: step == current ? 16 : 6, height: 6)
                }
            }
            // The pill stretches to the new step (spec 006). With Reduce Motion, a new set of dots
            // for each step, so it crossfades instead.
            .id(reduceMotion ? current : 0)
            .transition(.opacity)

            Text(
                "Step \(current) of \(total) · \(Text(name))",
                comment: "Assistant footer. First value: current step number; second: total steps; third: step name."
            )
            .font(Theme.Fonts.footnote)
            .foregroundStyle(Theme.Colors.secondary)
            // The step number rolls like a counter.
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(current)))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: current)
        // VoiceOver reads the label only; the dots are decorative.
        .accessibilityElement(children: .combine)
    }

    private func color(of step: Int) -> Color {
        // Always the accent color, also when a step fails or the assistant is done: the screen
        // already says so, and another color would clash with the other pills (spec 005).
        step <= current ? Theme.Colors.accent : Color.secondary.opacity(0.3)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StepIndicator(current: 1, total: 4, name: "Installer")
        StepIndicator(current: 3, total: 4, name: "Review")
        StepIndicator(current: 4, total: 4, name: "Creation")
    }
    .padding()
}
