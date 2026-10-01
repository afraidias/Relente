//
//  SimulationLabel.swift
//  Relente
//
//  Says, under the header of Creating, Error and Done, that the creation is only simulated, so
//  it can't be mistaken for the real thing. Debug builds only use it, until roadmap step 7.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

struct SimulationLabel: View {
    var body: some View {
        Label {
            Text(
                "SIMULATION · Nothing is erased",
                comment: "Label shown while the creation is only simulated (Debug builds).")
        } icon: {
            Image(systemName: "testtube.2")
        }
        .font(Theme.Fonts.sectionLabel)
        // Dark text on the orange fill reads well in light and dark mode.
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.Colors.warning, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        SimulationLabel()
        SimulationLabel()
            .environment(\.colorScheme, .dark)
            .padding()
            .background(.black)
    }
    .padding()
}
