//
//  NoInstallerView.swift
//  Relente
//
//  Step 1, no installers: shown under the screen's header until an installer appears in
//  /Applications or the user chooses one (option C3 of the design canvas).
//  Spec: specs/007-real-detection/spec.md
//

import SwiftUI

struct NoInstallerView: View {
    let onDownload: () -> Void
    let onChoose: () -> Void

    var body: some View {
        EmptyStateView(
            title: LocalizedStringResource(
                "No Installers Found", comment: "Empty state title on the Installer screen."),
            systemImage: "arrow.down.app",
            description: Text(
                "Download one from Apple, or choose one you already have.",
                comment: "Empty state on the Installer screen when no installer is found."
            ),
            waitingText: LocalizedStringResource(
                "Waiting for an installer…", comment: "Shown while no macOS installer has been found.")
        ) {
            VStack(spacing: 8) {
                Button(action: onDownload) {
                    Label("Download from Apple…", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.primary)

                Button("Already have one? Choose Installer…", action: onChoose)
                    .buttonStyle(.link)
            }
        }
    }
}

#Preview {
    NoInstallerView(onDownload: {}, onChoose: {})
        .frame(width: 800, height: 400)
}
