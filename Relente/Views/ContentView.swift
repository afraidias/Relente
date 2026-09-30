//
//  ContentView.swift
//  Relente
//
//  Assistant container: current screen on top, footer at the bottom.
//  For now it only shows the Installer screen; navigation comes later.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedInstallerID = InstallerSource.samples.first?.id

    var body: some View {
        VStack(spacing: 0) {
            InstallerView(installers: InstallerSource.samples, selectedID: $selectedInstallerID)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            AssistantFooter(
                step: 1,
                totalSteps: 4,
                stepName: "Installer",
                canContinue: selectedInstallerID != nil
            ) {
                // TODO: go to the USB drive screen.
            }
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

#Preview {
    ContentView()
}
