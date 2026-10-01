//
//  AssistantFooter.swift
//  Relente
//
//  Bottom bar of the assistant: an optional help button and the step indicator on the left,
//  the screen's buttons on the right.
//

import SwiftUI

struct AssistantFooter<Leading: View, Actions: View>: View {
    let step: Int
    let totalSteps: Int
    let stepName: LocalizedStringResource
    /// Before the step indicator, e.g. the help button: Apple's guidelines put help in the
    /// bottom-leading corner, apart from the action buttons.
    let leading: Leading
    let actions: Actions

    init(
        step: Int,
        totalSteps: Int,
        stepName: LocalizedStringResource,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder actions: () -> Actions
    ) {
        self.step = step
        self.totalSteps = totalSteps
        self.stepName = stepName
        self.leading = leading()
        self.actions = actions()
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                leading
                StepIndicator(current: step, total: totalSteps, name: stepName)
            }

            Spacer()

            HStack(spacing: 12) {
                actions
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

extension AssistantFooter where Leading == EmptyView {
    /// A footer with nothing before the step indicator.
    init(
        step: Int,
        totalSteps: Int,
        stepName: LocalizedStringResource,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(step: step, totalSteps: totalSteps, stepName: stepName, leading: { EmptyView() }, actions: actions)
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
