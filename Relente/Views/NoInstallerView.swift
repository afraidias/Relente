//
//  NoInstallerView.swift
//  Relente
//
//  Step 1, no installers: shown under the screen's header until an installer appears in
//  /Applications or the user adds one with the dashed square, which takes the symbol's place.
//  Spec: specs/007-real-detection/spec.md
//

import SwiftUI

struct NoInstallerView: View {
    let onDownload: () -> Void
    let onChoose: () -> Void
    let onDrop: ([URL]) -> Bool

    var body: some View {
        EmptyStateView(
            title: LocalizedStringResource(
                "No Installers Found", comment: "Empty state title on the Installer screen."),
            description: Text(
                "Download one from Apple, or add one you already have.",
                comment: "Empty state on the Installer screen when no installer is found."
            ),
            waitingText: LocalizedStringResource(
                "Waiting for an installer…", comment: "Shown while no macOS installer has been found.")
        ) {
            AddInstallerButton(onChoose: onChoose, onDrop: onDrop)
        } actions: {
            Button(action: onDownload) {
                Label("Download from Apple…", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.primary)
        }
    }
}

#Preview {
    NoInstallerView(onDownload: {}, onChoose: {}, onDrop: { _ in true })
        .frame(width: 800, height: 400)
}
