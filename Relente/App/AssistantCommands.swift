//
//  AssistantCommands.swift
//  Relente
//
//  The Go menu: "Back" with ⌘[, the standard Mac shortcut for going back, so it can be found in
//  the menu bar. macOS moves the shortcut to the same key position on other keyboard layouts.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

struct AssistantCommands: Commands {
    let assistant: Assistant

    var body: some Commands {
        CommandMenu(Text("Go", comment: "Menu bar menu with commands to move through the assistant.")) {
            Button("Back", action: assistant.goBack)
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!assistant.canGoBack)
        }
    }
}
