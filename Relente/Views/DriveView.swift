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
                PickCollection(itemCount: drives.count, selection: selectedID, onMoveSelection: onMoveSelection) {
                    ForEach(drives) { drive in
                        DriveItem(
                            name: drive.name,
                            kind: drive.kind,
                            subtitle: drive.subtitle,
                            status: drive.status(forInstallerSize: installer.size),
                            capacity: drive.capacity,
                            usageFraction: drive.usageFraction,
                            requiredCapacity: Drive.requiredCapacity(forInstallerSize: installer.size),
                            isSelected: drive.id == selectedID
                        ) {
                            selectedID = drive.id
                        }
                    }
                }
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

/// One drive: illustration, name, and always three lines under it, so they line up across drives:
/// the model (or the kind of drive), a gray usage bar, and what's on it. A drive that's too small
/// has its red chip in the bar's place and its size and the size it needs below; it's disabled
/// (dimmed, not selectable).
/// Spec: specs/007-real-detection/spec.md (option C, aligned)
struct DriveItem: View {
    let name: String
    let kind: Drive.Kind
    /// "Kingston DataTraveler", or "USB Drive" when the name is the model.
    let subtitle: String
    let status: Drive.Status
    let capacity: Int64
    /// How full the usage bar is, from 0 to 1.
    let usageFraction: Double
    let requiredCapacity: Int64
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PickItem(title: name, isSelected: isSelected, action: action) {
            DriveArtwork(kind: kind)
                .sharedArtwork(.drive, isActive: isSelected)
        } detail: {
            VStack(spacing: 6) {
                Text(verbatim: subtitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(Text(verbatim: subtitle))

                // The chip or the bar, in a line as tall as the chip, so line 3 lines up too.
                Group {
                    if status == .tooSmall {
                        StatusChip(
                            text: LocalizedStringResource(
                                "Too small", comment: "Status chip under a drive smaller than the installer needs."),
                            tone: .error)
                    } else {
                        DriveUsageBar(fraction: usageFraction)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: Self.statusLineHeight)

                Text(status == .tooSmall ? tooSmallText : status.usage(capacity: capacity))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.Colors.secondary)
        }
        .disabled(!status.isSelectable)
    }

    /// Height of line 2: a status chip's.
    private static let statusLineHeight: CGFloat = 20

    /// "8 GB · needs 17.8 GB". A no-break space before "·", so a wrapped line never starts with it.
    private var tooSmallText: LocalizedStringResource {
        LocalizedStringResource(
            "\(capacity.formatted(.byteCount(style: .file)))\u{00A0}· needs \(requiredCapacity.formatted(.byteCount(style: .file)))",
            comment:
                "Under a drive that's too small. Values: its capacity and the size the installer needs, e.g. 8 GB and 17.8 GB."
        )
    }
}

/// A thin gray bar: the space in use over the drive's capacity. Gray, not a status color: nothing
/// is erased on this screen.
struct DriveUsageBar: View {
    let fraction: Double

    @Environment(\.pickItemSize) private var size

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.Colors.secondary)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            // As wide as the drive's plate.
            .frame(width: size.plateSide, height: 5)
    }
}

// MARK: - Usage text

extension Drive.Status {
    /// The gray text under the usage bar. A drive that's too small has its own text instead.
    func usage(capacity: Int64) -> LocalizedStringResource {
        let capacity = capacity.formatted(.byteCount(style: .file))
        return switch self {
        case .willErase(.bytes(let usedBytes)):
            LocalizedStringResource(
                "\(usedBytes.formatted(.byteCount(style: .file))) of \(capacity) in use",
                comment: "Under a drive's usage bar. Values: space in use and capacity, e.g. 10.89 GB of 15.52 GB."
            )
        // A no-break space before "·", so a line that wraps never starts with it.
        case .willErase(.unknown):
            LocalizedStringResource(
                "Contents unknown\u{00A0}· \(capacity)",
                comment:
                    "Under a drive whose data Relente can't measure (e.g. formatted for Linux). The value is its capacity."
            )
        case .empty, .tooSmall:
            LocalizedStringResource(
                "Empty\u{00A0}· \(capacity)", comment: "Under an empty drive's usage bar. The value is its capacity.")
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

#Preview("Many drives (grid)") {
    @Previewable @State var selectedID = Drive.samples.first?.id

    // Six drives: the grid of small items.
    DriveView(
        drives: Drive.samples + [Drive.unknownDataSample]
            + Drive.samples.prefix(2).map { drive in
                Drive(
                    id: drive.id + "-copy", bsdName: drive.bsdName, name: drive.name + " 2", model: drive.model,
                    kind: drive.kind, capacity: drive.capacity, usedSpace: drive.usedSpace)
            },
        installer: InstallerSource.samples[0], selectedID: $selectedID
    )
    .padding(32)
    .frame(width: 800, height: 480)
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
