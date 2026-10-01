//
//  RelenteApp.swift
//  Relente
//

import SwiftUI

@main
struct RelenteApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.usesClassicControls, Self.forcesClassicControls)
        }
        // Only the window buttons in the top bar, no title.
        .windowStyle(.hiddenTitleBar)
        // The window takes the content's fixed size and can't be resized.
        .windowResizability(.contentSize)
    }

    /// The assistant. In Debug builds, launching with `-startScreen done` or `-startScreen creating`
    /// opens that screen with sample data instead, to check it in the running app (VoiceOver,
    /// Reduce Motion, keyboard) until navigation exists (roadmap step 4). Always the assistant in
    /// Release.
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
            switch UserDefaults.standard.string(forKey: "startScreen") {
            case "done": DoneScreen(thisMac: .current)
            case "creating": CreatingScreen()
            default: ContentView()
            }
        #else
            ContentView()
        #endif
    }

    /// In Debug builds, launching with `-classicControls YES` shows the
    /// pre–Liquid Glass look used on macOS 14 and 15. Always off in Release.
    private static var forcesClassicControls: Bool {
        #if DEBUG
            UserDefaults.standard.bool(forKey: "classicControls")
        #else
            false
        #endif
    }
}
