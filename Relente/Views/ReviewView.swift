//
//  ReviewView.swift
//  Relente
//
//  Step 3: last look at the drive that will be erased and what will be put
//  on it, with a required confirmation before erasing.
//  Spec: specs/003-review-screen/spec.md
//

import SwiftUI

struct ReviewView: View {
    let installer: InstallerSource
    let drive: Drive
    /// Whether the user ticked "I understand…". It's cleared every time the screen appears.
    @Binding var hasConfirmed: Bool

    var body: some View {
        let summary = ReviewSummary(installer: installer, drive: drive)

        VStack(spacing: 0) {
            ScreenHeader(
                title: "Review and Create",
                subtitle: "Make sure this is the right drive. Everything on it will be erased."
            )

            Spacer(minLength: 16)

            ReviewHero(installer: installer, drive: drive)

            Spacer(minLength: 16)

            VStack(spacing: 20) {
                ReviewStats(installerName: installer.name, summary: summary)

                UsageBar(
                    installerName: installer.name,
                    driveName: drive.name,
                    installedBytes: summary.installedBytes,
                    freeBytes: summary.freeAfterwardsBytes,
                    capacity: drive.capacity,
                    installedFraction: summary.installedFraction
                )

                EraseWarning(driveName: drive.name, hasConfirmed: $hasConfirmed)
            }
            .frame(width: Theme.Sizes.contentWidth)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
        .onAppear { hasConfirmed = false }
    }
}

// MARK: - Hero

/// The chosen drive, big, with the installer's icon as a badge, and its name and capacity below.
struct ReviewHero: View {
    let installer: InstallerSource
    let drive: Drive

    var body: some View {
        VStack(spacing: 12) {
            HeroArtwork(size: 104) {
                DriveArtwork(kind: drive.kind)
                    .sharedArtwork(.drive)
            } badge: {
                FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                    .sharedArtwork(.installer)
            }

            Text(verbatim: "\(drive.name) · \(drive.detail)")
                .font(.body.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel(
                    Text(verbatim: "\(drive.name), \(drive.detail.replacingOccurrences(of: " · ", with: ", "))"))
        }
    }
}

// MARK: - Figures

/// WILL BE ERASED / WILL BE INSTALLED / FREE AFTERWARDS.
struct ReviewStats: View {
    let installerName: String
    let summary: ReviewSummary

    private var erasedValue: Text {
        if summary.erasesNothing {
            return Text("Nothing", comment: "Review screen: an empty drive has nothing to erase.")
        }
        return switch summary.erased {
        case .bytes(let bytes): Text(verbatim: bytes.formatted(.byteCount(style: .file)))
        case .unknown:
            Text(
                "Unknown size",
                comment:
                    "Review screen, WILL BE ERASED: the drive has data Relente can't measure (e.g. formatted for Linux)."
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            BigStat(
                label: LocalizedStringResource(
                    "WILL BE ERASED", comment: "Review screen figure: space in use on the drive, which will be lost."),
                value: erasedValue,
                tint: summary.erasesNothing ? Theme.Colors.secondary : Theme.Colors.warning
            )
            .frame(maxWidth: .infinity)

            BigStat(
                label: LocalizedStringResource(
                    "WILL BE INSTALLED", comment: "Review screen figure: size of the installer copied to the drive."),
                value: Text(verbatim: summary.installedBytes.formatted(.byteCount(style: .file))),
                caption: Text(verbatim: installerName)
            )
            .frame(maxWidth: .infinity)

            BigStat(
                label: LocalizedStringResource(
                    "FREE AFTERWARDS", comment: "Review screen figure: space left on the drive after creating it."),
                value: Text(verbatim: summary.freeAfterwardsBytes.formatted(.byteCount(style: .file)))
            )
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Usage bar

/// How the drive will look afterwards: the drive and its capacity, then two segments with a gap
/// (the installer in the accent color, free space in gray) and a legend with each part's size.
struct UsageBar: View {
    let installerName: String
    let driveName: String
    let installedBytes: Int64
    let freeBytes: Int64
    let capacity: Int64
    /// Share of the drive the installer takes, from 0 to 1.
    let installedFraction: Double

    /// Space between the installer's segment and the free one.
    private static let gap: CGFloat = 4
    /// The free segment never gets thinner than this, so it shows on an almost full drive.
    private static let minimumFreeWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(verbatim: driveName)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 16)
                Text(verbatim: Self.bytes(capacity))
            }
            .sectionLabelStyle()

            GeometryReader { proxy in
                let available = proxy.size.width - Self.gap
                let installedWidth = min(
                    available * installedFraction, available - Self.minimumFreeWidth)
                HStack(spacing: Self.gap) {
                    Capsule()
                        .fill(Theme.Colors.accent)
                        .frame(width: max(installedWidth, 0))
                    Capsule()
                        .fill(.quaternary)
                }
            }
            .frame(height: 8)

            HStack {
                legendItem(Text(verbatim: installerName), size: installedBytes, color: Theme.Colors.accent)
                Spacer(minLength: 16)
                legendItem(
                    Text("Free", comment: "Usage bar legend: free space on the drive."), size: freeBytes, color: .gray)
            }
            .font(Theme.Fonts.footnote)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(
            Text(
                "\(installerName) will use \(Self.bytes(installedBytes)) of \(Self.bytes(capacity)), \(Self.bytes(freeBytes)) free",
                comment:
                    "VoiceOver label of the usage bar. Values: installer name (e.g. macOS Tahoe), its size (16.8 GB), the drive's capacity (32 GB) and the space left (15.2 GB)."
            )
        )
    }

    /// "● macOS Tahoe 16.8 GB": the name in the primary color, the size in gray.
    private func legendItem(_ name: Text, size: Int64, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            name
                .fontWeight(.medium)
            Text(verbatim: Self.bytes(size))
                .foregroundStyle(Theme.Colors.secondary)
        }
        .lineLimit(1)
    }

    private static func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file))
    }
}

// MARK: - Warning

/// Orange warning with the required "I understand…" checkbox.
struct EraseWarning: View {
    let driveName: String
    @Binding var hasConfirmed: Bool

    var body: some View {
        WarningCallout(
            title: LocalizedStringResource(
                "Everything on “\(driveName)” will be permanently erased.",
                comment: "Review screen warning. The value is the drive's name, e.g. SanDisk Ultra."
            ),
            message: LocalizedStringResource(
                "This can't be undone. Other disks won't be touched.",
                comment: "Review screen warning, second line."
            )
        ) {
            Toggle(isOn: $hasConfirmed) {
                Text(
                    "I understand that all data on this drive will be lost.",
                    comment: "Required checkbox before erasing the drive."
                )
            }
            .toggleStyle(.checkbox)
        }
    }
}

// MARK: - Footer

/// "Back" and the red "Erase and Create" button, enabled only after confirming.
/// "Erase and Create" is never the default action, so Return can't erase a drive.
struct ReviewFooter: View {
    let hasConfirmed: Bool
    /// False in Release builds until roadmap step 7: the button stays disabled, with a help tag.
    var canCreate = true
    let onBack: () -> Void
    let onErase: () -> Void

    var body: some View {
        AssistantFooter(for: .review) {
            BackButton(action: onBack)

            Button(role: .destructive, action: onErase) {
                Label {
                    Text("Erase and Create", comment: "Button that erases the drive and creates the installer.")
                } icon: {
                    // It asks for Touch ID (or the password; see spec 005, open items).
                    Image(systemName: "touchid")
                }
            }
            .buttonStyle(.primary)
            .tint(Theme.Colors.danger)
            .disabled(!hasConfirmed || !canCreate)
            .help(
                canCreate
                    ? Text(verbatim: "")
                    : Text(
                        "Available in a later version.",
                        comment:
                            "Help tag of the disabled Erase and Create button, before creating installers is built."))
        }
    }
}

// MARK: - Previews

/// The whole screen as it will appear in the window: content and footer.
private struct ReviewScreenPreview: View {
    let drive: Drive
    var canCreate = true
    @State private var hasConfirmed = false

    var body: some View {
        VStack(spacing: 0) {
            ReviewView(installer: InstallerSource.samples[0], drive: drive, hasConfirmed: $hasConfirmed)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ReviewFooter(hasConfirmed: hasConfirmed, canCreate: canCreate, onBack: {}, onErase: {})
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

#Preview("Drive with data") {
    ReviewScreenPreview(drive: Drive.samples[0])
}

#Preview("Empty drive") {
    ReviewScreenPreview(drive: Drive.samples[1])
}

#Preview("Data of unknown size") {
    ReviewScreenPreview(drive: Drive.unknownDataSample)
}

#Preview("Can't create yet (Release)") {
    ReviewScreenPreview(drive: Drive.samples[0], canCreate: false)
}

#Preview("Classic (macOS 14–15)") {
    ReviewScreenPreview(drive: Drive.samples[0])
        .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    ReviewScreenPreview(drive: Drive.samples[0])
        .preferredColorScheme(.dark)
}
