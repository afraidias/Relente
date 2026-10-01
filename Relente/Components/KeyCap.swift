//
//  KeyCap.swift
//  Relente
//
//  One key of a Mac keyboard, drawn small, such as "F12", the power button or
//  "⌥ option". The key to press is highlighted in the accent color.
//

import SwiftUI

struct KeyCap: View {

    /// What's printed on the key.
    enum Face: Hashable {
        /// A word, such as "F12" or "fn".
        case text(String)
        /// An SF Symbol, such as `power`.
        case symbol(String)
        /// A modifier: its glyph over its name, as on the keyboard, e.g. "⌥" over "option".
        case modifier(glyph: String, name: String)
    }

    let face: Face
    /// Whether this is the key to press.
    var isHighlighted = false

    var body: some View {
        content
            .foregroundStyle(isHighlighted ? Theme.Colors.accent : Theme.Colors.secondary)
            // Every key is the same height, whatever is printed on it.
            .frame(minWidth: isHighlighted ? 38 : 34)
            .frame(height: isHighlighted ? 34 : 30)
            .padding(.horizontal, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHighlighted ? Theme.Colors.accent.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Theme.Colors.accent : Color(nsColor: .separatorColor),
                        lineWidth: isHighlighted ? 2 : 1
                    )
            }
            // Keys are a drawing; the card around them says which key to press.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch face {
        case .text(let text):
            Text(verbatim: text)
                .font(.caption2)
        case .symbol(let name):
            Image(systemName: name)
                .font(.caption.weight(.semibold))
        case .modifier(let glyph, let name):
            VStack(spacing: 0) {
                Text(verbatim: glyph)
                    .font(.caption)
                Text(verbatim: name)
                    .font(.caption2)
            }
        }
    }
}

#Preview {
    HStack(spacing: 6) {
        KeyCap(face: .text("F12"))
        KeyCap(face: .symbol("power"), isHighlighted: true)
        KeyCap(face: .text("fn"))
        KeyCap(face: .modifier(glyph: "⌃", name: "control"))
        KeyCap(face: .modifier(glyph: "⌥", name: "option"), isHighlighted: true)
        KeyCap(face: .modifier(glyph: "⌘", name: "command"))
    }
    .padding()
}
