//
//  DriveView.swift
//  Relente
//
//  Step 2: pick the USB drive or SD card that will become the installer.
//  Spec: specs/002-drive-screen/spec.md
//

import SwiftUI

struct DriveView: View {
    let drives: [Drive]
    /// Size of the chosen installer, in bytes. It decides which drives are big enough.
    let installerSize: Int64
    @Binding var selectedID: Drive.ID?

    var body: some View {
        if drives.isEmpty {
            NoDriveView(requiredCapacity: Drive.requiredCapacity(forInstallerSize: installerSize))
        } else {
            VStack(spacing: 0) {
                ScreenHeader(
                    title: "Choose a USB Drive",
                    subtitle: "Everything on the drive you choose will be erased."
                )

                Spacer()

                HStack(spacing: 24) {
                    ForEach(drives) { drive in
                        DriveItem(
                            name: drive.name,
                            kind: drive.kind,
                            formattedCapacity: drive.formattedCapacity,
                            status: drive.status(forInstallerSize: installerSize),
                            requiredCapacity: Drive.requiredCapacity(forInstallerSize: installerSize),
                            isSelected: drive.id == selectedID
                        ) {
                            selectedID = drive.id
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 8)
        }
    }
}

/// One drive: illustration, name, capacity and status chip.
/// Drives that can't be used are disabled (dimmed, not selectable).
struct DriveItem: View {
    let name: String
    let kind: Drive.Kind
    let formattedCapacity: String
    let status: Drive.Status
    let requiredCapacity: Int64
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PickItem(title: name, isSelected: isSelected, action: action) {
            DriveArtwork(kind: kind)
        } detail: {
            VStack(spacing: 6) {
                Text(verbatim: formattedCapacity)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondary)

                StatusChip(text: status.label, tone: status.tone)

                if status == .tooSmall {
                    Text(
                        "Needs \(requiredCapacity.formatted(.byteCount(style: .file)))",
                        comment: "Under a drive that's too small. The value is the minimum size, e.g. 17.8 GB."
                    )
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.secondary)
                }
            }
        }
        .disabled(!status.isSelectable)
    }
}

// MARK: - Status appearance

extension Drive.Status {
    /// Text of the status chip.
    var label: LocalizedStringResource {
        switch self {
        case .willErase(let usedBytes):
            LocalizedStringResource(
                "\(usedBytes.formatted(.byteCount(style: .file))) will be erased",
                comment: "Status chip under a drive that has data. The value is the space in use, e.g. 9.8 GB."
            )
        case .empty:
            LocalizedStringResource("Empty", comment: "Status chip under a drive with nothing on it.")
        case .tooSmall:
            LocalizedStringResource(
                "Too small", comment: "Status chip under a drive smaller than the installer needs.")
        }
    }

    /// Color and icon of the status chip.
    var tone: StatusChip.Tone {
        switch self {
        case .willErase: .warning
        case .empty: .ok
        case .tooSmall: .error
        }
    }
}

// MARK: - Previews

#Preview("Liquid Glass (macOS 26+)") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installerSize: 16_800_000_000, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("Classic (macOS 14–15)") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installerSize: 16_800_000_000, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .environment(\.usesClassicControls, true)
}

#Preview("No drive") {
    @Previewable @State var selectedID: Drive.ID?

    DriveView(drives: [], installerSize: 16_800_000_000, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}
