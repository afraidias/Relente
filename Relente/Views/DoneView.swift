//
//  DoneView.swift
//  Relente
//
//  Step 5: the bootable installer is ready. The drive with its new name, and how to
//  start up a Mac from it, shown on a strip of each kind of Mac's keyboard.
//  Spec: specs/005-done-screen/spec.md
//

import SwiftUI

struct DoneView: View {
    let result: CreationResult
    /// The kind of Mac in use, whose start-up card is marked "This Mac".
    let thisMac: MacArchitecture
    /// Whether the creation was only simulated (Debug builds): a label then says so.
    var isSimulated = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Installer Ready",
                subtitle: Text(
                    "Eject it and plug it into the Mac where you want to install macOS. It took \(Text(result.durationText)).",
                    comment: "Done screen subtitle. The value is how long it took, e.g. 12 minutes."
                )
            )

            if isSimulated {
                SimulationLabel()
                    .padding(.top, 8)
            }

            Spacer(minLength: 8)

            DoneHero(result: result)

            Spacer(minLength: 8)

            DoneStartUp(result: result, thisMac: thisMac)
                .frame(width: Theme.Sizes.contentWidth)

            Spacer(minLength: 8)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
    }
}

// MARK: - Hero

/// The drive with a green halo and the installer's icon as its badge, checked, and the name the
/// drive has now, which is what the user will look for when starting up the Mac.
struct DoneHero: View {
    let result: CreationResult

    var body: some View {
        VStack(spacing: 12) {
            HeroArtwork(size: 104, haloColor: Theme.Colors.success) {
                DriveArtwork(kind: result.drive.kind)
                    .sharedArtwork(.drive)
            } badge: {
                InstallerBadge(installer: result.installer, isChecked: true)
                    .sharedArtwork(.installer)
            }

            Text(
                "“\(result.volumeName)”",
                comment: "Done screen, under the drive: the name it has now, in quotes, e.g. “Install macOS Tahoe”."
            )
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "\(result.volumeName), on \(result.drive.name)",
                comment:
                    "VoiceOver, Done screen drive. First value: its new name; second: the drive, e.g. SanDisk Ultra."
            )
        )
    }
}

// MARK: - Start up from the drive

/// One card per kind of Mac, side by side, the same height.
struct DoneStartUp: View {
    let result: CreationResult
    let thisMac: MacArchitecture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("START UP FROM THE DRIVE", comment: "Done screen section label above the start-up cards.")
                .sectionLabelStyle()

            HStack(alignment: .top, spacing: 12) {
                ForEach(MacArchitecture.allCases, id: \.self) { architecture in
                    StartUpCard(
                        architecture: architecture,
                        volumeName: result.volumeName,
                        isThisMac: architecture == thisMac
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What to try when the drive doesn't show up at start-up, one entry per cause.
struct DoneHelp: View {
    /// E.g. "macOS Tahoe", for the entry about which Macs support it.
    let installerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drive not showing up at start-up?", comment: "Title of the Done screen's help popover.")
                .font(.headline)

            HelpCause(
                symbol: "externaldrive.badge.plus",
                title: LocalizedStringResource("Connection", comment: "Done screen help: cause title."),
                text: LocalizedStringResource(
                    "Plug it straight into the Mac, not into a hub, and try another port.",
                    comment: "Done screen help: what to do about the connection.")
            )
            HelpCause(
                symbol: "cpu",
                title: LocalizedStringResource(
                    "Intel Mac with the T2 chip (2018–2020)", comment: "Done screen help: cause title."),
                text: LocalizedStringResource(
                    "Start up in Recovery (⌘R) and, in Startup Security Utility, allow booting from external media.",
                    comment: "Done screen help. Use the macOS names of Recovery, the utility and the option.")
            )
            HelpCause(
                symbol: "laptopcomputer",
                title: LocalizedStringResource("Compatibility", comment: "Done screen help: cause title."),
                text: LocalizedStringResource(
                    "It only shows up on Macs that support \(installerName).",
                    comment: "Done screen help. The value is the macOS version, e.g. macOS Tahoe.")
            )
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }
}

/// One cause in the help: a large accent symbol, a bold title and one line.
private struct HelpCause: View {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // As Apple's guidelines say: sized by the font of the text next to it (large scale
            // for list icons) rather than resized, sitting on the title's baseline, in a fixed
            // column so the texts line up whatever each symbol's width.
            Image(systemName: symbol)
                .imageScale(.large)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(text)
                    .foregroundStyle(Theme.Colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(Theme.Fonts.footnote)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Footer

/// Help in the bottom-leading corner, where Apple's guidelines put it, and "Eject", the default
/// action: ejecting erases nothing, so Return can do it.
struct DoneFooter: View {
    /// E.g. "macOS Tahoe", for the help entry about which Macs support it.
    let installerName: String
    let onEject: () -> Void

    @State private var isShowingHelp: Bool

    /// `isShowingHelp` opens the help popover from the start, for previews.
    init(installerName: String, isShowingHelp: Bool = false, onEject: @escaping () -> Void) {
        self.installerName = installerName
        self.onEject = onEject
        _isShowingHelp = State(initialValue: isShowingHelp)
    }

    var body: some View {
        AssistantFooter(for: .done) {
            HelpLink {
                isShowingHelp = true
            }
            .popover(isPresented: $isShowingHelp, arrowEdge: .top) {
                DoneHelp(installerName: installerName)
            }
        } actions: {
            Button(action: onEject) {
                Label {
                    Text("Eject", comment: "Done screen button: eject the drive and go back to the first step.")
                } icon: {
                    Image(systemName: "eject")
                }
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Whole screen

/// The whole screen as it appears in the window: content and footer, for the previews.
struct DoneScreen: View {
    var result = CreationResult.sample
    var thisMac = MacArchitecture.appleSilicon
    var isShowingHelp = false
    var isSimulated = false

    var body: some View {
        VStack(spacing: 0) {
            DoneView(result: result, thisMac: thisMac, isSimulated: isSimulated)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            DoneFooter(installerName: result.installer.name, isShowingHelp: isShowingHelp, onEject: {})
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

// MARK: - Previews

#Preview("Apple silicon") {
    DoneScreen()
}

#Preview("Intel") {
    DoneScreen(thisMac: .intel)
}

#Preview("Longest name (Big Sur)") {
    DoneScreen(
        result: CreationResult(
            installer: InstallerSource(
                url: URL(filePath: "/Applications/Install macOS Big Sur.app"),
                name: "macOS Big Sur",
                version: "11.7.10",
                kind: .app,
                size: 12_400_000_000
            ),
            drive: Drive.samples[1],
            duration: .seconds(80 * 60)
        )
    )
}

#Preview("Under a minute") {
    DoneScreen(
        result: CreationResult(installer: InstallerSource.samples[0], drive: Drive.samples[0], duration: .seconds(45))
    )
}

#Preview("Simulated") {
    DoneScreen(isSimulated: true)
}

#Preview("Help open") {
    DoneScreen(isShowingHelp: true)
}

#Preview("Classic (macOS 14–15)") {
    DoneScreen()
        .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    DoneScreen()
        .preferredColorScheme(.dark)
}
