//
//  LiveDiskFormatter.swift
//  RelenteHelper
//
//  Runs `DiskutilCommand`: a fixed executable path and an argument array, never a shell (helper
//  rule 1). Cancelling ends `diskutil`; the drive is then unusable until it's erased again.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

actor LiveDiskFormatter: DiskFormatting {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private var process: Process?

    func format(_ bsdName: String) async -> Bool {
        guard let arguments = DiskutilCommand.eraseArguments(for: bsdName) else { return false }
        let process = Process()
        process.executableURL = DiskutilCommand.executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        self.process = process
        defer { self.process = nil }

        Self.logger.info("Erasing \(bsdName, privacy: .public)")
        let status: Int32? = await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationReason == .exit ? finished.terminationStatus : nil)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: nil)
            }
        }
        // diskutil writes a few lines; they fit in the pipe, so reading them afterwards can't block.
        let text = (try? output.fileHandleForReading.readToEnd()).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if status == 0 {
            Self.logger.info("Erased \(bsdName, privacy: .public)")
            return true
        }
        Self.logger.error(
            "diskutil failed on \(bsdName, privacy: .public) (\(status.map(String.init) ?? "stopped", privacy: .public)): \(text, privacy: .public)"
        )
        return false
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        Self.logger.info("Stopping diskutil")
        process.terminate()
    }
}
