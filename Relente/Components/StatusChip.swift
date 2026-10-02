//
//  StatusChip.swift
//  Relente
//
//  Small colored label with an icon, such as "Too small" or "Not supported".
//

import SwiftUI

struct StatusChip: View {

    /// The chip's color and icon, from the design system.
    enum Tone {
        case ok
        case warning
        case info
        case error
        case neutral

        var color: Color {
            switch self {
            case .ok: Theme.Colors.success
            case .warning: Theme.Colors.warning
            case .info: Theme.Colors.accent
            case .error: Theme.Colors.danger
            case .neutral: Theme.Colors.secondary
            }
        }

        var systemImage: String {
            switch self {
            case .ok: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            case .error: "xmark.octagon.fill"
            case .neutral: "minus.circle.fill"
            }
        }
    }

    let text: LocalizedStringResource
    let tone: Tone

    /// Under a small item (`PickItemSize.compact`) the chip has no icon, so "Too small" fits; its
    /// text says what the icon would.
    @Environment(\.pickItemSize) private var itemSize

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if itemSize == .regular {
                Image(systemName: tone.systemImage)
            }
        }
        .font(Theme.Fonts.sectionLabel)
        .foregroundStyle(tone.color)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StatusChip(text: "This Mac", tone: .ok)
        StatusChip(text: "Unknown size", tone: .warning)
        StatusChip(text: "This Mac", tone: .info)
        StatusChip(text: "Too small", tone: .error)
        StatusChip(text: "Not supported", tone: .neutral)
    }
    .padding()
}
