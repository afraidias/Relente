//
//  RelenteApp.swift
//  Relente
//

import SwiftUI

@main
struct RelenteApp: App {
    @State private var assistant = Assistant(
        installerService: Self.installerService,
        driveService: Self.driveService,
        creationService: Self.creationService
    )

    var body: some Scene {
        WindowGroup {
            AssistantView(assistant: assistant, thisMac: .current)
                .environment(\.usesClassicControls, Self.forcesClassicControls)
                .task { await assistant.start() }
        }
        // Only the window buttons in the top bar, no title.
        .windowStyle(.hiddenTitleBar)
        // The window takes the content's fixed size and can't be resized.
        .windowResizability(.contentSize)
        .commands {
            AssistantCommands(assistant: assistant)
        }
    }

    // MARK: - Services

    /// Whether to show the sample installers and drives instead of the Mac's: always under unit
    /// tests, which must never read the Mac's disks, and in Debug builds launched with
    /// `-sampleData YES`.
    private static var usesSampleData: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
        #if DEBUG
            return UserDefaults.standard.bool(forKey: "sampleData")
        #else
            return false
        #endif
    }

    private static var installerService: any InstallerService {
        usesSampleData ? SampleInstallerService() : LiveInstallerService()
    }

    private static var driveService: any DriveService {
        usesSampleData ? SampleDriveService() : LiveDriveService()
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
