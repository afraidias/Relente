//
//  AddInstallerButton.swift
//  Relente
//
//  A dashed square with a plus: click it to choose an installer saved anywhere, or drop one on
//  it from the Finder. The last item of the Installer screen's row, and the empty state's
//  symbol. No text: the plus says "add"; the help tag and VoiceOver say what it takes.
//  Spec: specs/007-real-detection/spec.md
//

import SwiftUI

struct AddInstallerButton: View {
    let onChoose: () -> Void
    let onDrop: ([URL]) -> Bool

    @Environment(\.pickItemSize) private var size
    @State private var isTargeted = false

    var body: some View {
        Button(action: onChoose) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isTargeted ? Theme.Colors.accent.opacity(0.12) : .clear)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(isTargeted ? AnyShapeStyle(Theme.Colors.accent) : AnyShapeStyle(.tertiary))
                Image(systemName: "plus")
                    .font(.system(size: size == .regular ? 28 : 20, weight: .medium))
                    .foregroundStyle(isTargeted ? AnyShapeStyle(Theme.Colors.accent) : AnyShapeStyle(.secondary))
            }
            // The same place an installer's icon takes in its item.
            .frame(width: size.plateSide - 28, height: size.plateSide - 28)
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(Text(Self.hint))
        .accessibilityLabel(Text("Add Installer…", comment: "VoiceOver name of the dashed square with a plus."))
        .accessibilityHint(Text(Self.hint))
        .dropDestination(for: URL.self) { urls, _ in
            onDrop(urls)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private static let hint = LocalizedStringResource(
        "Choose or drop an installer app, disk image or InstallAssistant.pkg.",
        comment: "Help tag and VoiceOver hint of the dashed square with a plus on the Installer screen.")
}

#Preview {
    AddInstallerButton(onChoose: {}, onDrop: { _ in true })
        .padding()
}
