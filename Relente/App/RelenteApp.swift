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

    /// With sample data, `-sampleEmpty installers` or `-sampleEmpty drives` starts with that list
    /// empty, to show its empty state. Unit tests make their own services.
    private static var sampleEmpty: String? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "sampleEmpty")
        #else
            nil
        #endif
    }

    private static var installerService: any InstallerService {
        guard usesSampleData else { return LiveInstallerService() }
        // Catalina too, so the sample data shows an unsupported installer as well.
        let installers = InstallerSource.samples + [InstallerSource.unsupportedSample]
        return SampleInstallerService(installers: sampleEmpty == "installers" ? [] : installers)
    }

    private static var driveService: any DriveService {
        guard usesSampleData else { return LiveDriveService() }
        return SampleDriveService(drives: sampleEmpty == "drives" ? [] : Drive.samples)
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
