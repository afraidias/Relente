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
    /// The chosen installer: shown in the label under the header, and its size decides which
    /// drives are big enough.
    let installer: InstallerSource
    @Binding var selectedID: Drive.ID?
    /// Left and right arrows: -1 for the previous usable drive, +1 for the next.
    var onMoveSelection: (Int) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Choose a USB Drive",
                subtitle: "Everything on the drive you choose will be erased."
            )

            DriveInstallerLabel(installer: installer)
                .padding(.top, 12)

            if drives.isEmpty {
                NoDriveView(requiredCapacity: Drive.requiredCapacity(forInstallerSize: installer.size))
                    .frame(maxHeight: .infinity)
            } else {
                Spacer()

                HStack(spacing: 24) {
                    ForEach(drives) { drive in
                        DriveItem(
                            name: drive.name,
                            kind: drive.kind,
                            detail: drive.detail,
                            status: drive.status(forInstallerSize: installer.size),
                            requiredCapacity: Drive.requiredCapacity(forInstallerSize: installer.size),
                            isSelected: drive.id == selectedID
                        ) {
                            selectedID = drive.id
                        }
                    }
                }
                .selectsWithArrowKeys(onMoveSelection)
                .slidingSelection(selectedID)

                Spacer()
            }
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
    }
}

// MARK: - Installer label

/// A reminder of what will go on the drive: the chosen installer's icon, name, version and size.
/// Not a control. The installer's icon travels through it on its way to Review (spec 006).
struct DriveInstallerLabel: View {
    let installer: InstallerSource

    var body: some View {
        HStack(spacing: 6) {
            FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                .frame(width: 16, height: 16)
                .sharedArtwork(.installer)
            Text(verbatim: installer.name)
                .fontWeight(.semibold)
            Text(verbatim: "\(installer.version) · \(installer.formattedSize)")
                .foregroundStyle(Theme.Colors.secondary)
        }
        .font(Theme.Fonts.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.fill.tertiary, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(
            Text(
                "Installer: \(installer.name) \(installer.version.description), \(installer.formattedSize)",
                comment:
                    "VoiceOver label of the installer reminder on the USB Drive screen. Values: name, version and size, e.g. macOS Tahoe, 26.0, 16.8 GB."
            )
        )
    }
}

/// One drive: illustration, name, model and capacity, and status chip.
/// Drives that can't be used are disabled (dimmed, not selectable).
struct DriveItem: View {
    let name: String
    let kind: Drive.Kind
    /// "SanDisk Ultra · 32 GB", or only the capacity when the name is the model.
    let detail: String
    let status: Drive.Status
    let requiredCapacity: Int64
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PickItem(title: name, isSelected: isSelected, action: action) {
            DriveArtwork(kind: kind)
                .sharedArtwork(.drive, isActive: isSelected)
        } detail: {
            VStack(spacing: 6) {
                Text(verbatim: detail)
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
        case .willErase(.bytes(let usedBytes)):
            LocalizedStringResource(
                "\(usedBytes.formatted(.byteCount(style: .file))) will be erased",
                comment: "Status chip under a drive that has data. The value is the space in use, e.g. 9.8 GB."
            )
        case .willErase(.unknown):
            LocalizedStringResource(
                "Data will be erased",
                comment: "Status chip under a drive that has data Relente can't measure (e.g. formatted for Linux)."
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

// MARK: - Footer

/// "Back" and "Continue"; Continue, the default action, needs a drive that can be used.
struct DriveFooter: View {
    let canContinue: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        AssistantFooter(for: .drive) {
            BackButton(action: onBack)

            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
    }
}

// MARK: - Previews

#Preview("Liquid Glass (macOS 26+)") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installer: InstallerSource.samples[0], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("Classic (macOS 14–15)") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installer: InstallerSource.samples[0], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .environment(\.usesClassicControls, true)
}

#Preview("Spanish") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installer: InstallerSource.samples[0], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Dark") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    DriveView(drives: Drive.samples, installer: InstallerSource.samples[0], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .preferredColorScheme(.dark)
}

#Preview("Data of unknown size") {
    @Previewable @State var selectedID: Drive.ID?

    DriveView(
        drives: [Drive.samples[1], Drive.unknownDataSample], installer: InstallerSource.samples[0],
        selectedID: $selectedID
    )
    .padding(32)
    .frame(width: 800, height: 480)
}

#Preview("No drive") {
    @Previewable @State var selectedID: Drive.ID?

    DriveView(drives: [], installer: InstallerSource.samples[0], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("Footer") {
    VStack(spacing: 0) {
        DriveFooter(canContinue: true, onBack: {}, onContinue: {})
        DriveFooter(canContinue: false, onBack: {}, onContinue: {})
    }
    .frame(width: 800)
}
