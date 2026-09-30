//
//  CreatingView.swift
//  Relente
//
//  Step 4: the bootable installer being made, with its progress around the drive,
//  the copy figures and the phase bar. Step 4b, when it stops, keeps the same layout
//  in red, with why it stopped in the subtitle and where in the figures.
//  Spec: specs/004-creating-screen/spec.md
//

import SwiftUI

struct CreatingView: View {
    let installer: InstallerSource
    let drive: Drive
    /// Running, or stopped with a reason. Both share this layout, so the screen doesn't jump.
    let state: CreationState

    /// Width shared by the figures and the phase bar, as on the Review screen.
    private let contentWidth: CGFloat = 560

    var body: some View {
        let progress = state.progress

        VStack(spacing: 0) {
            if let failure = state.failure {
                ScreenHeader(title: "Couldn't Create the Installer", subtitle: Self.subtitle(for: failure.reason))
            } else {
                ScreenHeader(
                    title: "Creating Installer",
                    subtitle: "Keep the drive plugged in. This can take a while."
                )
            }

            Spacer(minLength: 8)

            CreatingHero(installer: installer, drive: drive, progress: progress, isFailed: state.failure != nil)

            Spacer(minLength: 8)

            VStack(spacing: 24) {
                if let failure = state.failure {
                    // Keeps the height of the three figures (which have a caption), so nothing moves.
                    CreatingStats(progress: progress)
                        .hidden()
                        .overlay(alignment: .top) {
                            FailureStats(failure: failure)
                        }
                } else {
                    CreatingStats(progress: progress)
                }

                PhaseBar(
                    current: progress.phase,
                    currentFraction: progress.phaseFraction ?? 0,
                    isFailed: state.failure != nil
                )
            }
            .frame(width: contentWidth)

            // Free space is shared evenly above and below the hero and at the bottom. Both
            // states are the same height, so it's shared the same way and nothing jumps.
            Spacer(minLength: 8)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
    }

    /// The Error screen's subtitle: why it stopped, in the primary color, then what to do.
    private static func subtitle(for reason: CreationFailure.Reason) -> Text {
        Text(
            "\(Text(reason.title).foregroundStyle(.primary)) \(Text(reason.recovery))",
            comment: "Error screen subtitle. First value: why it stopped; second: what to do. Both are full sentences."
        )
    }
}

// MARK: - Hero

/// The drive inside the progress ring, the overall percentage, and the drive's name and capacity.
/// When it stopped, everything turns red, the ring stays where it was and the percentage moves
/// to STOPPED AT.
struct CreatingHero: View {
    let installer: InstallerSource
    let drive: Drive
    let progress: CreationProgress
    let isFailed: Bool

    var body: some View {
        let tint = isFailed ? Theme.Colors.danger : Theme.Colors.accent

        VStack(spacing: 10) {
            ProgressRing(
                fraction: progress.overallFraction,
                label: isFailed
                    ? Text("Stopped", comment: "VoiceOver label of the progress ring after a failure.")
                    : Text("Creating installer", comment: "VoiceOver label of the progress ring."),
                value: Text(progress.percent, format: .percent),
                diameter: 140,
                tint: tint
            ) {
                HeroArtwork(size: 90, haloColor: tint) {
                    DriveArtwork(kind: drive.kind)
                } badge: {
                    if isFailed {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .foregroundStyle(.white, Theme.Colors.danger)
                    } else {
                        FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                    }
                }
            }

            // When it stopped, the percentage moves to STOPPED AT. Its space is kept (so nothing
            // below moves) but goes under the name, so the name stays right under the ring.
            VStack(spacing: 2) {
                if isFailed {
                    driveName
                    percentage
                        .hidden()
                } else {
                    percentage
                    driveName
                }
            }
        }
    }

    private var percentage: some View {
        Text(progress.percent, format: .percent)
            .font(Theme.Fonts.figure)
            // The ring already reads the percentage.
            .accessibilityHidden(true)
    }

    private var driveName: some View {
        Text(verbatim: "\(drive.name) · \(drive.formattedCapacity)")
            .font(Theme.Fonts.footnote)
            .foregroundStyle(Theme.Colors.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(Text(verbatim: "\(drive.name), \(drive.formattedCapacity)"))
    }
}

// MARK: - Figures

/// COPIED / SPEED / REMAINING.
struct CreatingStats: View {
    let progress: CreationProgress

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            BigStat(
                label: LocalizedStringResource(
                    "COPIED", comment: "Creating screen figure: bytes of the installer copied to the drive so far."),
                value: Text(verbatim: Self.bytes(progress.displayedCopiedBytes)),
                caption: Text(
                    "of \(Self.bytes(progress.installerSize))",
                    comment: "Creating screen, under COPIED. The value is the installer's size, e.g. 16.8 GB."
                )
            )
            .frame(maxWidth: .infinity)

            BigStat(
                label: LocalizedStringResource(
                    "SPEED", comment: "Creating screen figure: how fast the installer is being copied."),
                value: speed
            )
            .frame(maxWidth: .infinity)

            BigStat(
                label: LocalizedStringResource(
                    "REMAINING", comment: "Creating screen figure: estimated time left."),
                value: Text(progress.remaining.text)
            )
            .frame(maxWidth: .infinity)
        }
    }

    /// "48 MB/s", or a dash while there's no speed to show.
    private var speed: Text {
        guard let bytesPerSecond = progress.displayedBytesPerSecond else { return Text(verbatim: "—") }
        return Text(
            "\(Self.bytes(bytesPerSecond))/s",
            comment: "Creating screen, SPEED. The value is an amount of data, e.g. 48 MB; the figure is per second."
        )
    }

    /// Bytes formatted for people, writing zero as "0 bytes" rather than "Zero KB".
    private static func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file, spellsOutZero: false))
    }
}

/// STOPPED AT, shown instead of the copy figures when it stopped. No caption: the phase bar
/// already shows the phase it stopped in.
struct FailureStats: View {
    let failure: CreationFailure

    var body: some View {
        BigStat(
            label: LocalizedStringResource(
                "STOPPED AT", comment: "Error screen figure: overall progress when creating stopped."),
            value: Text(failure.stoppedPercent, format: .percent),
            tint: Theme.Colors.danger
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Footer

/// "Cancel", which asks before stopping. "Keep Going" is the default (Return);
/// "Stop" is never the default.
struct CreatingFooter: View {
    let driveName: String
    let onStop: () -> Void

    @State private var isConfirmingCancel = false

    var body: some View {
        AssistantFooter(step: 4, totalSteps: 4, stepName: "Creating") {
            Button("Cancel") {
                isConfirmingCancel = true
            }
            .buttonStyle(.secondary)
        }
        .alert(
            Text("Stop creating the installer?", comment: "Title of the alert shown when cancelling the creation."),
            isPresented: $isConfirmingCancel
        ) {
            Button(role: .cancel) {
            } label: {
                Text("Keep Going", comment: "Alert button: don't stop, keep creating the installer.")
            }
            // Return keeps going. A native alert gives each button one key, so Esc then does
            // nothing (spec decision 8).
            .keyboardShortcut(.defaultAction)

            Button(role: .destructive, action: onStop) {
                Text("Stop", comment: "Alert button: stop creating the installer.")
            }
        } message: {
            Text(
                "“\(driveName)” will be left unusable until it's erased again.",
                comment: "Message of the cancel alert. The value is the drive's name, e.g. SanDisk Ultra."
            )
        }
    }
}

/// "Start Over" and "Try Again". "Try Again" is the default: it only goes back to Review,
/// where erasing has to be confirmed again.
/// The step's pill turns red, like the rest of the screen.
struct CreationErrorFooter: View {
    let onStartOver: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        AssistantFooter(step: 4, totalSteps: 4, stepName: "Creating", stepTint: Theme.Colors.danger) {
            Button(action: onStartOver) {
                Text("Start Over", comment: "Error screen button: go back to the first step.")
            }
            .buttonStyle(.secondary)

            Button(action: onTryAgain) {
                Text("Try Again", comment: "Error screen button: go back to Review with the same drive and installer.")
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Previews

/// The whole screen as it will appear in the window: content and footer.
private struct CreatingScreenPreview: View {
    let state: CreationState

    var body: some View {
        VStack(spacing: 0) {
            CreatingView(installer: InstallerSource.samples[0], drive: Drive.samples[0], state: state)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.failure == nil {
                CreatingFooter(driveName: Drive.samples[0].name, onStop: {})
            } else {
                CreationErrorFooter(onStartOver: {}, onTryAgain: {})
            }
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

#Preview("Format") {
    CreatingScreenPreview(state: .running(.sampleFormat))
}

#Preview("Copy, speed unknown") {
    CreatingScreenPreview(state: .running(.sampleEarlyCopy))
}

#Preview("Copy") {
    CreatingScreenPreview(state: .running(.sampleMidCopy))
}

#Preview("Make bootable") {
    CreatingScreenPreview(state: .running(.sampleMakeBootable))
}

#Preview("Verify") {
    CreatingScreenPreview(state: .running(.sampleVerify))
}

#Preview("Error: drive disconnected") {
    CreatingScreenPreview(state: .failed(.sampleDriveDisconnected))
}

#Preview("Error: cancelled") {
    CreatingScreenPreview(state: .failed(.sampleCancelled))
}

#Preview("Classic (macOS 14–15)") {
    CreatingScreenPreview(state: .running(.sampleMidCopy))
        .environment(\.usesClassicControls, true)
}

#Preview("Error, classic (macOS 14–15)") {
    CreatingScreenPreview(state: .failed(.sampleDriveDisconnected))
        .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    CreatingScreenPreview(state: .running(.sampleMidCopy))
        .preferredColorScheme(.dark)
}

#Preview("Error, dark") {
    CreatingScreenPreview(state: .failed(.sampleDriveDisconnected))
        .preferredColorScheme(.dark)
}
