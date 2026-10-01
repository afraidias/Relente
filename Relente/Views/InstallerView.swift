//
//  InstallerView.swift
//  Relente
//
//  Step 1: pick the macOS installer to copy to the USB drive.
//  Spec: specs/001-installer-screen/spec.md
//

import SwiftUI

struct InstallerView: View {
    let installers: [InstallerSource]
    @Binding var selectedID: InstallerSource.ID?
    /// Left and right arrows: -1 for the previous installer, +1 for the next.
    var onMoveSelection: (Int) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Choose an Installer",
                subtitle: "Pick the version of macOS you want on the USB drive."
            )

            Spacer()

            HStack(spacing: 24) {
                ForEach(installers) { installer in
                    PickItem(
                        title: installer.name,
                        isSelected: installer.id == selectedID
                    ) {
                        selectedID = installer.id
                    } icon: {
                        FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                            .sharedArtwork(.installer, isActive: installer.id == selectedID)
                    } detail: {
                        Text(verbatim: "\(installer.version) · \(installer.formattedSize)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    .help(installer.url.path(percentEncoded: false))
                }
            }
            .selectsWithArrowKeys(onMoveSelection)
            .slidingSelection(selectedID)

            Spacer()

            Button {
                // TODO: open the download screen (1b).
            } label: {
                Label("Download from Apple…", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.secondary)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
    }
}

// MARK: - Footer

/// "Continue", the default action, enabled once an installer is chosen.
struct InstallerFooter: View {
    let canContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        AssistantFooter(for: .installer) {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    InstallerView(installers: InstallerSource.samples, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("Footer") {
    InstallerFooter(canContinue: true, onContinue: {})
        .frame(width: 800)
}
