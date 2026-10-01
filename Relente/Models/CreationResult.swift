//
//  CreationResult.swift
//  Relente
//
//  What the Done screen shows: the installer made on the drive, how long it took,
//  and the name the drive has now.
//  Spec: specs/005-done-screen/spec.md
//

import Foundation

nonisolated struct CreationResult: Hashable, Sendable {
    let installer: InstallerSource
    let drive: Drive
    /// From the start of Format to the end of Verify.
    let duration: Duration

    /// The name `createinstallmedia` gives the volume, e.g. "Install macOS Tahoe". It's the name
    /// the user will look for in the Mac's start-up options. Read from the drive in roadmap step 7.
    var volumeName: String {
        "Install \(installer.name)"
    }

    /// The total time, in words, e.g. "12 minutes": "less than a minute" under 60 s, otherwise
    /// rounded to the nearest minute, as REMAINING on the Creating screen.
    var durationText: LocalizedStringResource {
        if duration < .seconds(60) {
            return LocalizedStringResource(
                "less than a minute", comment: "Done screen subtitle, how long it took: under 60 seconds.")
        }
        let minutes = (Double(duration.components.seconds) / 60).rounded()
        let rounded = Duration.seconds(Int64(minutes) * 60)
        return LocalizedStringResource(
            "\(rounded, format: .units(allowed: [.hours, .minutes], width: .wide))",
            comment:
                "Done screen subtitle, how long it took. The value is a duration, e.g. 12 minutes or 1 hour, 5 minutes."
        )
    }
}

// MARK: - Sample data

nonisolated extension CreationResult {
    /// macOS Tahoe on the SanDisk Ultra in 12 minutes, for the previews.
    static let sample = CreationResult(
        installer: InstallerSource.samples[0],
        drive: Drive.samples[0],
        duration: .seconds(720)
    )
}
