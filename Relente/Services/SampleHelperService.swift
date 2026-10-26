//
//  SampleHelperService.swift
//  Relente
//
//  A pretend system helper for previews, tests and `-sampleData YES`: nothing is registered with
//  macOS. Registering waits for approval, which comes by itself after a moment (or when a test
//  calls `approve()`), so the whole Permissions screen can be walked.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

nonisolated final class SampleHelperService: HelperService {
    /// How long until a registration is approved by itself, or `nil` to wait for `approve()`.
    private let approvalDelay: Duration?
    private let registerError: HelperError?
    private let unregisterError: HelperError?
    private let state: OSAllocatedUnfairLock<HelperStatus>

    init(
        status: HelperStatus = .ready, approvalDelay: Duration? = .seconds(1), registerError: HelperError? = nil,
        unregisterError: HelperError? = nil
    ) {
        state = OSAllocatedUnfairLock(initialState: status)
        self.approvalDelay = approvalDelay
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    var status: HelperStatus {
        state.withLock { $0 }
    }

    func register() async throws(HelperError) {
        if let registerError { throw registerError }
        state.withLock { $0 = .needsApproval }
        guard let approvalDelay else { return }
        Task {
            try? await Task.sleep(for: approvalDelay)
            approve()
        }
    }

    func unregister() async throws(HelperError) {
        if let unregisterError { throw unregisterError }
        state.withLock { $0 = .notInstalled }
    }

    func openSettings() {}

    /// As if the user turned the helper on in System Settings.
    func approve() {
        state.withLock { if $0 == .needsApproval { $0 = .ready } }
    }
}
