//
//  RelenteApp.swift
//  Relente
//

import SwiftUI

@main
struct RelenteApp: App {
    @State private var assistant = Assistant(
        installers: InstallerSource.samples,
        drives: Drive.samples,
        creationService: Self.creationService
    )

    var body: some Scene {
        WindowGroup {
            AssistantView(assistant: assistant, thisMac: .current)
                .environment(\.usesClassicControls, Self.forcesClassicControls)
        }
        // Only the window buttons in the top bar, no title.
        .windowStyle(.hiddenTitleBar)
        // The window takes the content's fixed size and can't be resized.
        .windowResizability(.contentSize)
        .commands {
            AssistantCommands(assistant: assistant)
        }
    }

    /// How the installer is made. Until roadmap step 7 only Debug builds have one: a simulation
    /// that erases nothing and says so on screen. `-simulationSpeed fast` makes it last about 2 s
    /// and `-simulateFailure driveDisconnected` makes it fail during Copy. Release builds have
    /// none, so "Erase and Create" stays disabled (spec 006).
    private static var creationService: (any CreationService)? {
        #if DEBUG
            let defaults = UserDefaults.standard
            return SimulatedCreationService(
                speed: .init(launchArgument: defaults.string(forKey: "simulationSpeed")),
                failure: SimulatedCreationService.failure(launchArgument: defaults.string(forKey: "simulateFailure"))
            )
        #else
            return nil
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
