//
//  AssistantFooter.swift
//  Relente
//
//  Bottom bar of the assistant: an optional help button and the step indicator on the left,
//  the screen's buttons on the right. Inside the assistant, the step indicator is drawn by
//  `AssistantView`, one for every screen, so the step can move instead of being redrawn.
//

import SwiftUI

struct AssistantFooter<Leading: View, Actions: View>: View {
    let step: AssistantStep
    /// Before the step indicator, e.g. the help button: Apple's guidelines put help in the
    /// bottom-leading corner, apart from the action buttons.
    let leading: Leading
    let actions: Actions

    init(
        for step: AssistantStep,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder actions: () -> Actions
    ) {
        self.step = step
        self.leading = leading()
        self.actions = actions()
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                leading
                StepIndicator(current: step.stepNumber, total: AssistantStep.stepCount, name: step.stepName)
                    .sharedArtwork(.stepIndicator)
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
    init(for step: AssistantStep, @ViewBuilder actions: () -> Actions) {
        self.init(for: step, leading: { EmptyView() }, actions: actions)
    }
}

#Preview {
    AssistantFooter(for: .installer) {
        Button("Continue") {}
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
    }
    .frame(width: 800)
}
