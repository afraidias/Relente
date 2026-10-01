//
//  CreatingView.swift
//  Relente
//
//  Step 4: the bootable installer being made, with its progress around the drive,
//  the copy figures and the phase bar. Step 4b, when it stops, keeps the same layout
//  in red, with why it stopped in the subtitle and where in the figures.
//  Spec: specs/004-creating-screen/spec.md
//

import AppKit
import SwiftUI

struct CreatingView: View {
    let installer: InstallerSource
    let drive: Drive
    /// Running, or stopped with a reason. Both share this layout, so the screen doesn't jump.
    let state: CreationState

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
            .frame(width: Theme.Sizes.contentWidth)

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
/// When it stopped, the halo and badge turn red, the ring goes away (keeping its space) and the
/// percentage moves to STOPPED AT.
struct CreatingHero: View {
    let installer: InstallerSource
    let drive: Drive
    let progress: CreationProgress
    let isFailed: Bool

    /// Size of the ring, and of the space it leaves when it's gone.
    private static let ringDiameter: CGFloat = 140

    var body: some View {
        let tint = isFailed ? Theme.Colors.danger : Theme.Colors.accent

        let artwork = HeroArtwork(size: 90, haloColor: tint) {
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

        VStack(spacing: 10) {
            if isFailed {
                // No ring once it stopped: the red halo and badge say it, and STOPPED AT says
                // where. The ring's space is kept, so nothing moves (spec 005).
                artwork
                    .frame(width: Self.ringDiameter, height: Self.ringDiameter)
            } else {
                ProgressRing(
                    fraction: progress.overallFraction,
                    label: Text("Creating installer", comment: "VoiceOver label of the progress ring."),
                    value: Text(progress.percent, format: .percent),
                    diameter: Self.ringDiameter,
                    tint: tint
                ) {
                    artwork
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

/// "Cancel", which asks before stopping. Esc presses it, as Apple's guidelines ask; it only opens
/// the confirmation.
struct CreatingFooter: View {
    let driveName: String
    let onStop: () -> Void

    @State private var isConfirmingCancel: Bool

    /// `isConfirmingCancel` opens the confirmation from the start, for previews.
    init(driveName: String, isConfirmingCancel: Bool = false, onStop: @escaping () -> Void) {
        self.driveName = driveName
        self.onStop = onStop
        _isConfirmingCancel = State(initialValue: isConfirmingCancel)
    }

    var body: some View {
        AssistantFooter(step: 4, totalSteps: 4, stepName: "Creation") {
            Button("Cancel") {
                isConfirmingCancel = true
            }
            .buttonStyle(.secondary)
            .keyboardShortcut(.cancelAction)
        }
        .sheet(isPresented: $isConfirmingCancel) {
            StopCreationSheet(
                driveName: driveName,
                onKeepGoing: { isConfirmingCancel = false },
                onStop: {
                    isConfirmingCancel = false
                    onStop()
                }
            )
        }
    }
}

/// Asks before stopping, looking like a macOS alert. A sheet rather than a native alert so that
/// Return *and* Esc keep going (a native alert gives each button one key); "Stop" is destructive
/// and only answers a click. Spec 005, "Apple's Human Interface Guidelines".
struct StopCreationSheet: View {
    let driveName: String
    let onKeepGoing: () -> Void
    let onStop: () -> Void

    var body: some View {
        // Laid out like a macOS alert: the app's icon (centered), then the title and message.
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Stop creating the installer?", comment: "Title of the alert shown when cancelling the creation.")
                    .font(.headline)
                Text(
                    "“\(driveName)” will be left unusable until it's erased again.",
                    comment: "Message of the cancel alert. The value is the drive's name, e.g. SanDisk Ultra."
                )
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(role: .destructive, action: onStop) {
                    Text("Stop", comment: "Alert button: stop creating the installer.")
                        .frame(maxWidth: .infinity)
                }
                // Gray like the other choice in a macOS alert; still destructive for VoiceOver.
                .buttonStyle(.secondary)

                Button(action: onKeepGoing) {
                    Text("Keep Going", comment: "Alert button: don't stop, keep creating the installer.")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                // Return keeps going…
                .keyboardShortcut(.defaultAction)
            }
            // Large, as in macOS alerts; side by side because there are two (Apple's guidelines).
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        // …and so does Esc.
        .onExitCommand(perform: onKeepGoing)
    }
}

/// "Start Over" and "Try Again". "Try Again" is the default: it only goes back to Review,
/// where erasing has to be confirmed again.
struct CreationErrorFooter: View {
    let onStartOver: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        AssistantFooter(step: 4, totalSteps: 4, stepName: "Creation") {
            Button(action: onStartOver) {
                Label {
                    Text("Start Over", comment: "Error screen button: go back to the first step.")
                } icon: {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            .buttonStyle(.secondary)

            Button(action: onTryAgain) {
                Label {
                    Text(
                        "Try Again",
                        comment: "Error screen button: go back to Review with the same drive and installer.")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Whole screen

/// The whole screen as it appears in the window: content and footer. Used by the previews and,
/// in Debug builds, by the `-startScreen creating` launch argument (see `RelenteApp`).
struct CreatingScreen: View {
    var state = CreationState.running(.sampleMidCopy)
    var isConfirmingCancel = false

    var body: some View {
        VStack(spacing: 0) {
            CreatingView(installer: InstallerSource.samples[0], drive: Drive.samples[0], state: state)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.failure == nil {
                CreatingFooter(driveName: Drive.samples[0].name, isConfirmingCancel: isConfirmingCancel, onStop: {})
            } else {
                CreationErrorFooter(onStartOver: {}, onTryAgain: {})
            }
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

// MARK: - Previews

#Preview("Format") {
    CreatingScreen(state: .running(.sampleFormat))
}

#Preview("Copy, speed unknown") {
    CreatingScreen(state: .running(.sampleEarlyCopy))
}

#Preview("Copy") {
    CreatingScreen(state: .running(.sampleMidCopy))
}

#Preview("Make bootable") {
    CreatingScreen(state: .running(.sampleMakeBootable))
}

#Preview("Verify") {
    CreatingScreen(state: .running(.sampleVerify))
}

#Preview("Error: drive disconnected") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
}

#Preview("Error: cancelled") {
    CreatingScreen(state: .failed(.sampleCancelled))
}

#Preview("Cancel confirmation") {
    CreatingScreen(isConfirmingCancel: true)
}

#Preview("Classic (macOS 14–15)") {
    CreatingScreen(state: .running(.sampleMidCopy))
        .environment(\.usesClassicControls, true)
}

#Preview("Error, classic (macOS 14–15)") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
        .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    CreatingScreen(state: .running(.sampleMidCopy))
        .preferredColorScheme(.dark)
}

#Preview("Error, dark") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
        .preferredColorScheme(.dark)
}
