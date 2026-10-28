import Foundation

nonisolated enum CreateInstallMediaOutcome: Int, Hashable, Sendable {
    case created = 0
    case notAuthorized = 1
    case invalidIdentifier = 2
    case driveNotAllowed = 3
    case driveChanged = 4
    case driveDisconnected = 5
    case invalidInstaller = 6
    case createFailed = 7
    case busy = 8
    case invalidVolume = 9
    case volumeAccessDenied = 10
}

nonisolated struct CreateInstallMediaUpdate: Hashable, Sendable {
    let progress: CreateInstallMediaProgress?
    let outputLine: String?
    let timestamp: Date
    let copyMeasurement: InstallerCopyMeasurement?
    let copyBytesPerSecond: Int64?

    init(
        progress: CreateInstallMediaProgress?, outputLine: String?, timestamp: Date,
        copyMeasurement: InstallerCopyMeasurement? = nil, copyBytesPerSecond: Int64? = nil
    ) {
        self.progress = progress
        self.outputLine = outputLine
        self.timestamp = timestamp
        self.copyMeasurement = copyMeasurement
        self.copyBytesPerSecond = copyBytesPerSecond
    }
}
