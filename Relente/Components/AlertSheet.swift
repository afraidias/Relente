//
//  AlertSheet.swift
//  Relente
//
//  A confirmation that looks like a macOS alert but is a sheet, so that Return *and* Esc answer
//  the safe choice (a native alert gives each button one key); the other action only answers a
//  click. Used to stop a creation (spec 004) and to uninstall the helper (spec 008).
//

import AppKit
import SwiftUI

struct AlertSheet: View {
    let title: Text
    let message: Text
    /// The action that only answers a click, e.g. "Stop".
    let action: Text
    /// `.destructive` when the action loses the user's data.
    var actionRole: ButtonRole?
    /// The safe choice, which answers Return and Esc, e.g. "Keep Going".
    let safeChoice: Text
    let onAction: () -> Void
    let onSafeChoice: () -> Void

    var body: some View {
        // Laid out like a macOS alert: the app's icon (centered), then the title and message.
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                title
                    .font(.headline)
                message
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(role: actionRole, action: onAction) {
                    action
                        .frame(maxWidth: .infinity)
                }
                // Gray like the other choice in a macOS alert; still destructive for VoiceOver.
                .buttonStyle(.secondary)

                Button(action: onSafeChoice) {
                    safeChoice
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                // Return answers the safe choice…
                .keyboardShortcut(.defaultAction)
            }
            // Large, as in macOS alerts; side by side because there are two (Apple's guidelines).
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        // …and so does Esc.
        .onExitCommand(perform: onSafeChoice)
    }
}

#Preview {
    AlertSheet(
        title: Text(verbatim: "Uninstall the System Helper?"),
        message: Text(verbatim: "Relente can't create installers without it."),
        action: Text(verbatim: "Uninstall"), safeChoice: Text(verbatim: "Cancel"), onAction: {}, onSafeChoice: {})
}
