//
//  AssistantFooter.swift
//  Relente
//
//  Bottom bar of the assistant: step indicator on the left,
//  primary button on the right.
//

import SwiftUI

struct AssistantFooter: View {
    let step: Int
    let totalSteps: Int
    let stepName: LocalizedStringResource
    let canContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        HStack {
            StepIndicator(current: step, total: totalSteps, name: stepName)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    AssistantFooter(step: 1, totalSteps: 4, stepName: "Installer", canContinue: true, onContinue: {})
        .frame(width: 800)
}
