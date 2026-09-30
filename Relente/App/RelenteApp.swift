//
//  RelenteApp.swift
//  Relente
//

import SwiftUI

@main
struct RelenteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.usesClassicControls, Self.forcesClassicControls)
        }
        // Only the window buttons in the top bar, no title.
        .windowStyle(.hiddenTitleBar)
        // The window takes the content's fixed size and can't be resized.
        .windowResizability(.contentSize)
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
