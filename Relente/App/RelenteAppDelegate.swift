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
    private var isCancellingForQuit = false
    static let dismissDownloadSheets = Notification.Name("RelenteDismissDownloadSheetsForQuit")

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func notifyDownloadCompleted() async {
        await deliverNotification(body: "Installer ready")
    }

    func notifyDownloadCancelled() async {
        guard !isCancellingForQuit else { return }
        await deliverNotification(body: "The installer download was cancelled. Incomplete work was removed.")
    }

    private func notifyQuitCancellation() async {
        guard assistant?.isShowingDownloadCancelled == true, !isSampleData else { return }
        await deliverNotification(body: "The installer download was cancelled. Incomplete work was removed.")
    }

    private var isSampleData: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
        #if DEBUG
            return UserDefaults.standard.bool(forKey: "sampleData")
        #else
            return false
        #endif
    }

    func notifyDownloadFailed() async {
        await deliverNotification(body: "The installer couldn’t be obtained. Open Relente for details.")
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

    func requestQuit() {
        guard let assistant, assistant.isDownloadingInstaller else {
            NSApp.terminate(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "Installer Acquisition in Progress")
        alert.informativeText = String(
            localized: "Keep waiting, or cancel and wait for incomplete work to be cleaned up before quitting.")
        alert.addButton(withTitle: String(localized: "Keep Waiting"))
        alert.addButton(withTitle: String(localized: "Cancel Download and Quit"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        isCancellingForQuit = true
        Task {
            guard await assistant.prepareForTermination() else {
                isCancellingForQuit = false
                return
            }
            await notifyQuitCancellation()
            NotificationCenter.default.post(name: Self.dismissDownloadSheets, object: nil)
            while NSApp.windows.contains(where: { $0.attachedSheet != nil }) {
                try? await Task.sleep(for: .milliseconds(100))
            }
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let assistant else { return .terminateNow }
        if assistant.acquisitionError == .recoveryRequired {
            let alert = NSAlert()
            alert.messageText = String(localized: "Installer Recovery Needed")
            alert.informativeText = String(
                localized:
                    "Relente cannot confirm that its incomplete work is safely stopped and cleaned up. Keep the app open and review the recovery details."
            )
            alert.addButton(withTitle: String(localized: "Keep Relente Open"))
            alert.runModal()
            return .terminateCancel
        }
        if assistant.isDownloadingInstaller {
            let alert = NSAlert()
            alert.messageText = String(localized: "Installer Acquisition in Progress")
            alert.informativeText = String(
                localized: "Keep waiting, or cancel and wait for incomplete work to be cleaned up before quitting.")
            alert.addButton(withTitle: String(localized: "Keep Waiting"))
            alert.addButton(withTitle: String(localized: "Cancel Download and Quit"))
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        } else if !assistant.isLoadingAvailableInstallers {
            return .terminateNow
        }
        isCancellingForQuit = true
        Task {
            let safe = await assistant.prepareForTermination()
            if safe { await notifyQuitCancellation() }
            if !safe { isCancellingForQuit = false }
            sender.reply(toApplicationShouldTerminate: safe)
        }
        return .terminateLater
    }
}
