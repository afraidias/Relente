//
//  LiveHelperService.swift
//  Relente
//
//  The system helper through `SMAppService`: a launch daemon whose plist is inside the app
//  (`Contents/Library/LaunchDaemons/`). macOS asks the user to turn it on in System Settings ›
//  General › Login Items the first time.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import ServiceManagement
import os

nonisolated struct LiveHelperService: HelperService {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private var daemon: SMAppService { .daemon(plistName: HelperIdentity.plistName) }

    var status: HelperStatus {
        switch daemon.status {
        case .enabled: .ready
        case .requiresApproval: .needsApproval
        // `notFound` means the plist isn't in the app; registering then fails with the reason.
        case .notRegistered, .notFound: .notInstalled
        @unknown default: .notInstalled
        }
    }

    func register() async throws(HelperError) {
        do {
            try daemon.register()
            Self.logger.info("Helper registered")
        } catch {
            // The first time, macOS refuses until the user turns it on: that's not a failure.
            if daemon.status == .requiresApproval {
                Self.logger.info("Helper registered, waiting for approval")
                return
            }
            Self.logger.error("Couldn't register the helper: \(error.localizedDescription, privacy: .public)")
            throw .registrationFailed(reason: error.localizedDescription)
        }
    }

    func unregister() async throws(HelperError) {
        do {
            try await daemon.unregister()
            Self.logger.info("Helper unregistered")
        } catch {
            Self.logger.error("Couldn't unregister the helper: \(error.localizedDescription, privacy: .public)")
            throw .unregistrationFailed(reason: error.localizedDescription)
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
