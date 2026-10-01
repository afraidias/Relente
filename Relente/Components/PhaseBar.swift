//
//  PhaseBar.swift
//  Relente
//
//  The phases of making the installer as equal segments with a label under each:
//  finished ones filled with a checkmark, the current one filling up, the rest gray.
//

import SwiftUI

struct PhaseBar: View {
    /// The phase in progress, or the one it stopped in.
    let current: CreationPhase
    /// Progress within the current phase, from 0 to 1.
    let currentFraction: Double
    /// Whether it stopped: the current segment turns red and stays where it was.
    var isFailed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phases = CreationPhase.allCases

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(phases, id: \.self) { phase in
                segment(for: phase)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Segment

    private func segment(for phase: CreationPhase) -> some View {
        let state = state(of: phase)

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(isFailed && state == .current ? Theme.Colors.danger : Theme.Colors.accent)
                        .frame(width: filledWidth(of: phase, in: proxy.size))
                }
            }
            .frame(height: 6)
            .animation(reduceMotion ? nil : .smooth, value: fill(of: phase))

            HStack(spacing: 4) {
                if state == .finished {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.accent)
                        .fontWeight(.bold)
                }
                Text(phase.name)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .foregroundStyle(state == .current ? .primary : Theme.Colors.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(Theme.Fonts.footnote)
        }
    }

    // MARK: - State

    private enum SegmentState {
        case finished, current, pending
    }

    private var currentIndex: Int {
        phases.firstIndex(of: current) ?? 0
    }

    private func state(of phase: CreationPhase) -> SegmentState {
        let index = phases.firstIndex(of: phase) ?? 0
        if index < currentIndex { return .finished }
        return index == currentIndex ? .current : .pending
    }

    /// Width of the filled part. Any progress shows at least a round dot, never a hairline.
    private func filledWidth(of phase: CreationPhase, in size: CGSize) -> CGFloat {
        let fill = fill(of: phase)
        return fill > 0 ? max(size.width * fill, size.height) : 0
    }

    /// How much of the segment is filled, from 0 to 1.
    private func fill(of phase: CreationPhase) -> Double {
        switch state(of: phase) {
        case .finished: 1
        case .current: min(max(currentFraction, 0), 1)
        case .pending: 0
        }
    }

    // MARK: - Accessibility

    /// "Phase 2 of 4, Copy", or "Stopped in phase 2 of 4, Copy".
    private var accessibilityText: Text {
        let number = currentIndex + 1
        let total = phases.count
        let name = Text(current.name)
        return isFailed
            ? Text(
                "Stopped in phase \(number) of \(total), \(name)",
                comment:
                    "VoiceOver label of the phase bar after a failure. Values: phase number, total phases, phase name."
            )
            : Text(
                "Phase \(number) of \(total), \(name)",
                comment:
                    "VoiceOver label of the phase bar. Values: phase number, total phases, phase name (e.g. Copy)."
            )
    }
}

#Preview {
    VStack(spacing: 28) {
        PhaseBar(current: .format, currentFraction: 0.6)
        PhaseBar(current: .copy, currentFraction: 0.43)
        PhaseBar(current: .makeBootable, currentFraction: 0)
        PhaseBar(current: .verify, currentFraction: 0.5)
        PhaseBar(current: .copy, currentFraction: 0.43, isFailed: true)
    }
    .frame(width: Theme.Sizes.contentWidth)
    .padding(32)
}
