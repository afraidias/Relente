//
//  RelenteAppDelegate.swift
//  Relente
//

import AppKit
@preconcurrency import UserNotifications
import os

@MainActor
final class RelenteAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var assistant: Assistant?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func notifyDownloadCancelled() async {
        await deliverNotification(body: "Cancellation requested. macOS may continue downloading.")
    }

    func notifyDownloadFailed() async {
        await deliverNotification(body: "The macOS installer download failed. Open Relente to try again.")
    }

    private func deliverNotification(body: LocalizedStringResource) async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert]) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Relente"
            content.body = String(localized: body)
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            Logger(subsystem: "com.afraidias.Relente", category: "ui")
                .error("Couldn't deliver download notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let assistant, assistant.isDownloadingInstaller else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = String(localized: "Download in Progress")
        alert.informativeText = String(localized: "Wait for the download to finish before quitting Relente.")
        alert.addButton(withTitle: String(localized: "Keep Waiting"))
        alert.runModal()
        return .terminateCancel
    }
}
