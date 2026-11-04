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
    /// Apple doesn't report a percentage for some live phases, such as copying essential files.
    var isIndeterminate = false
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
        .accessibilityElement(children: .contain)
    }

    // MARK: - Segment

    private func segment(for phase: CreationPhase) -> some View {
        let state = state(of: phase)

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                if state == .current, isIndeterminate {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                        let indicatorWidth = max(proxy.size.width * 0.42, proxy.size.height)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                            Capsule()
                                .fill(isFailed ? Theme.Colors.danger : Theme.Colors.accent)
                                .frame(width: indicatorWidth)
                                .offset(
                                    x: indeterminateOffset(
                                        at: timeline.date,
                                        in: proxy.size.width,
                                        indicatorWidth: indicatorWidth
                                    ))
                        }
                        .clipped()
                    }
                } else {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                        Capsule()
                            .fill(isFailed && state == .current ? Theme.Colors.danger : Theme.Colors.accent)
                            .frame(width: filledWidth(of: phase, in: proxy.size))
                    }
                }
            }
            .frame(height: 6)
            .animation(reduceMotion ? nil : .smooth, value: fill(of: phase))

            HStack(spacing: 5) {
                Image(systemName: phase.symbol)
                    .foregroundStyle(state == .current ? Theme.Colors.accent : Theme.Colors.secondary)
                    .accessibilityHidden(true)
                Text(phase.name)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .foregroundStyle(state == .current ? .primary : Theme.Colors.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(Theme.Fonts.footnote)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(phase.name), \(accessibilityStatus(for: state))"))
            .accessibilityIdentifier("creation.phase.\(phase.identifier)")
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

    /// The visible segment sweeps across the active phase; Reduce Motion leaves it centered.
    private func indeterminateOffset(at date: Date, in width: CGFloat, indicatorWidth: CGFloat) -> CGFloat {
        guard !reduceMotion else { return (width - indicatorWidth) / 2 }
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
        return (width + indicatorWidth) * cycle - indicatorWidth
    }

    /// How much of the segment is filled, from 0 to 1.
    private func fill(of phase: CreationPhase) -> Double {
        switch state(of: phase) {
        case .finished: 1
        case .current: min(max(currentFraction, 0), 1)
        case .pending: 0
        }
    }

    private func accessibilityStatus(for state: SegmentState) -> LocalizedStringResource {
        switch state {
        case .finished: "Completed"
        case .current: "In progress"
        case .pending: "Pending"
        }
    }
}
