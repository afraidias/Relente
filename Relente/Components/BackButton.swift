//
//  BackButton.swift
//  Relente
//
//  The assistant's "Back". It answers Esc, since the screens that have it have no Cancel button.
//  ⌘[ is in the Go menu (`AssistantCommands`), where people can find it.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button("Back", action: action)
            .buttonStyle(.secondary)
            .keyboardShortcut(.cancelAction)
    }
}

#Preview {
    BackButton {}
        .padding()
}
