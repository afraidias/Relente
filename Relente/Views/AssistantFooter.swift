//
//  AssistantFooter.swift
//  Relente
//
//  Bottom bar of the assistant: step indicator on the left,
//  the screen's buttons on the right.
//

import SwiftUI

struct AssistantFooter<Actions: View>: View {
    let step: Int
    let totalSteps: Int
    let stepName: LocalizedStringResource
    /// Color of the current step's pill; danger when the step failed.
    let stepTint: Color
    let actions: Actions

    init(
        step: Int,
        totalSteps: Int,
        stepName: LocalizedStringResource,
        stepTint: Color = Theme.Colors.accent,
        @ViewBuilder actions: () -> Actions
    ) {
        self.step = step
        self.totalSteps = totalSteps
        self.stepName = stepName
        self.stepTint = stepTint
        self.actions = actions()
    }

    var body: some View {
        HStack {
            StepIndicator(current: step, total: totalSteps, name: stepName, currentTint: stepTint)

            Spacer()

            HStack(spacing: 12) {
                actions
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    AssistantFooter(step: 1, totalSteps: 4, stepName: "Installer") {
        Button("Continue") {}
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
    }
    .frame(width: 800)
}
