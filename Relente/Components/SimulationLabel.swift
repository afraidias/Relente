//
//  SimulationLabel.swift
//  Relente
//
//  Labels sample-data creation in Debug so it cannot be mistaken for the live helper flow.
//

import SwiftUI

struct SimulationLabel: View {
    let simulation: CreationSimulation

    var body: some View {
        Label {
            switch simulation {
            case .everything:
                Text(
                    "SIMULATION · Nothing is erased",
                    comment: "Label shown while the creation is only simulated (Debug builds).")
            case .afterFormat:
                Text(
                    "SIMULATION · Only the format is real",
                    comment: "Label shown when the drive is really erased but the rest is simulated (Debug builds).")
            }
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
        SimulationLabel(simulation: .everything)
        SimulationLabel(simulation: .afterFormat)
            .environment(\.colorScheme, .dark)
            .padding()
            .background(.black)
    }
    .padding()
}
