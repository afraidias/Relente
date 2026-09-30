//
//  ProgressRing.swift
//  Relente
//
//  A circular progress arc over a gray track, drawn around other content,
//  such as the drive while the installer is being made.
//

import SwiftUI

struct ProgressRing<Content: View>: View {
    /// How much of the ring is filled, from 0 to 1.
    let fraction: Double
    /// What VoiceOver says the ring is, e.g. "Creating installer".
    let label: Text
    /// What VoiceOver reads as the ring's value, e.g. "43%". Passed in, already rounded,
    /// so it always matches the percentage on screen.
    let value: Text
    /// Diameter of the ring.
    let diameter: CGFloat
    /// Color of the filled arc: accent while running, danger when it stopped.
    let tint: Color
    let lineWidth: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        fraction: Double,
        label: Text,
        value: Text,
        diameter: CGFloat = 150,
        tint: Color = Theme.Colors.accent,
        lineWidth: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) {
        self.fraction = fraction
        self.label = label
        self.value = value
        self.diameter = diameter
        self.tint = tint
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                // Start at 12 o'clock and fill clockwise.
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .smooth, value: fraction)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    HStack(spacing: 48) {
        ForEach([0, 0.05, 0.41, 1], id: \.self) { fraction in
            ProgressRing(
                fraction: fraction,
                label: Text(verbatim: "Creating installer"),
                value: Text(Int(fraction * 100), format: .percent)
            ) {
                HeroArtwork(size: 96) {
                    DriveArtwork(kind: .usbDrive)
                }
            }
        }

        ProgressRing(
            fraction: 0.41,
            label: Text(verbatim: "Stopped"),
            value: Text(41, format: .percent),
            tint: Theme.Colors.danger
        ) {
            HeroArtwork(size: 96, haloColor: Theme.Colors.danger) {
                DriveArtwork(kind: .sdCard)
            } badge: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .foregroundStyle(.white, Theme.Colors.danger)
            }
        }
    }
    .padding(48)
}
