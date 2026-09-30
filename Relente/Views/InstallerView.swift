//
//  InstallerView.swift
//  Relente
//
//  Step 1: pick the macOS installer to copy to the USB drive.
//

import SwiftUI

struct InstallerView: View {
    let installers: [InstallerSource]
    @Binding var selectedID: InstallerSource.ID?

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
                    } detail: {
                        Text(verbatim: "\(installer.version) · \(installer.formattedSize)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    .help(installer.url.path(percentEncoded: false))
                }
            }

            Spacer()

            Button("Download from Apple…") {
                // TODO: open the download screen (1b).
            }
            .buttonStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

#Preview {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    InstallerView(installers: InstallerSource.samples, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}
