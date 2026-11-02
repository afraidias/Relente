//
//  ProcessSoftwareUpdateRunner.swift
//  Relente
//
//  Runs a fixed executable with argument arrays and captures or streams its output directly.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Darwin
import Foundation

actor ProcessSoftwareUpdateRunner: SoftwareUpdateRunning {
    private var process: Process?
    private var continuation: AsyncStream<SoftwareUpdateCommandEvent>.Continuation?
    private var cancellationRequested = false

    func run(executable: URL, arguments: [String]) async throws(SoftwareUpdateRunError)
        -> SoftwareUpdateCommandResult
    {
        try await Self.runToCompletion(executable: executable, arguments: arguments)
    }

    func stream(executable: URL, arguments: [String]) async -> AsyncStream<SoftwareUpdateCommandEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SoftwareUpdateCommandEvent.self)
        guard process == nil else {
            continuation.yield(.failed)
            continuation.finish()
            return stream
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            continuation.yield(.failed)
            continuation.finish()
            return stream
        }

        self.process = process
        self.continuation = continuation
        cancellationRequested = false
        Task {
            await readOutput(from: output)
        }
        return stream
    }

    func cancel() async {
        guard let process, process.isRunning else { return }
        cancellationRequested = true
        let processIdentifier = process.processIdentifier
        process.terminate()
        try? await Task.sleep(for: .seconds(2))
        guard process.isRunning else { return }
        _ = Darwin.kill(processIdentifier, SIGKILL)
    }

    private func readOutput(from pipe: Pipe) async {
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                continuation?.yield(.output(String(line)))
            }
            guard let process else { return }
            process.waitUntilExit()
            continuation?.yield(.finished(exitCode: process.terminationStatus, wasCancelled: cancellationRequested))
        } catch {
            continuation?.yield(.failed)
        }
        continuation?.finish()
        continuation = nil
        process = nil
        cancellationRequested = false
    }

    @concurrent
    private static func runToCompletion(executable: URL, arguments: [String]) async throws(SoftwareUpdateRunError)
        -> SoftwareUpdateCommandResult
    {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            throw .launchFailed
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return SoftwareUpdateCommandResult(
            exitCode: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }
}
