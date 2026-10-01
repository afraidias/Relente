//
//  StartUpCard.swift
//  Relente
//
//  How to start up one kind of Mac from the drive: a strip of its keyboard with the
//  key to hold highlighted, the kind of Mac with when to press it, and one or two lines
//  of text. The card of the Mac in use is marked "This Mac".
//  Spec: specs/005-done-screen/spec.md
//

import SwiftUI

struct StartUpCard: View {
    let architecture: MacArchitecture
    /// The name the drive has now, e.g. "Install macOS Tahoe".
    let volumeName: String
    let isThisMac: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            keyboard

            HStack(spacing: 6) {
                Text(architecture.name)
                    .font(.body.weight(.semibold))
                WhenToPressCapsule(text: architecture.whenToPress)
                if isThisMac {
                    StatusChip(
                        text: LocalizedStringResource(
                            "This Mac", comment: "Done screen: marks the start-up card that matches the Mac in use."),
                        tone: .ok
                    )
                }
            }
            .lineLimit(1)

            Text(architecture.startUpText(volumeName: volumeName))
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Keyboard

    /// A strip of the keyboard, keys in the order they have on a Mac keyboard.
    private var keyboard: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyCap(face: key.face, isHighlighted: key.isHighlighted)
            }
            if architecture == .appleSilicon {
                // The start-up options loading while the button is held.
                LoadingArc()
                    .padding(.leading, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quinary)
        }
        .accessibilityHidden(true)
    }

    private var keys: [(face: KeyCap.Face, isHighlighted: Bool)] {
        switch architecture {
        case .appleSilicon:
            // On Apple silicon keyboards the power button (Touch ID) comes right after F12.
            [(.text("F10"), false), (.text("F11"), false), (.text("F12"), false), (.symbol("power"), true)]
        case .intel:
            [
                (.text("fn"), false),
                (.modifier(glyph: "⌃", name: "control"), false),
                (.modifier(glyph: "⌥", name: "option"), true),
                (.modifier(glyph: "⌘", name: "command"), false),
            ]
        }
    }

    // MARK: - Accessibility

    /// E.g. "Apple silicon, this Mac: Hold the power button until…".
    private var accessibilityText: Text {
        let text = Text(architecture.startUpText(volumeName: volumeName))
        if isThisMac {
            return Text(
                "\(Text(architecture.name)), this Mac: \(text)",
                comment:
                    "VoiceOver, Done screen card of the Mac in use. First value: Apple silicon or Intel; second: what to do."
            )
        }
        return Text(
            "\(Text(architecture.name)): \(text)",
            comment: "VoiceOver, Done screen card. First value: Apple silicon or Intel; second: what to do.")
    }
}

// MARK: - Pieces

/// Accent capsule saying when to press the key, e.g. "HOLD".
private struct WhenToPressCapsule: View {
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.Colors.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.Colors.accent.opacity(0.12), in: Capsule())
    }
}

/// A short accent arc over a gray track, like the start-up options loading.
private struct LoadingArc: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }
}

#Preview {
    HStack(alignment: .top, spacing: 12) {
        StartUpCard(architecture: .appleSilicon, volumeName: "Install macOS Tahoe", isThisMac: true)
        StartUpCard(architecture: .intel, volumeName: "Install macOS Tahoe", isThisMac: false)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: Theme.Sizes.contentWidth)
    .padding()
}

#Preview("Dark, Intel Mac") {
    HStack(alignment: .top, spacing: 12) {
        StartUpCard(architecture: .appleSilicon, volumeName: "Install macOS Big Sur", isThisMac: false)
        StartUpCard(architecture: .intel, volumeName: "Install macOS Big Sur", isThisMac: true)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: Theme.Sizes.contentWidth)
    .padding()
    .preferredColorScheme(.dark)
}
