//
//  UninstallHelperSheet.swift
//  Relente
//
//  Asks before uninstalling the system helper. Return and Esc cancel; "Uninstall" only answers a
//  click. It loses no data, so it isn't destructive, but it undoes the setup.
//  Spec: specs/008-system-helper/spec.md
//

import SwiftUI

struct UninstallHelperSheet: View {
    let onUninstall: () -> Void
    let onCancel: () -> Void

    var body: some View {
        AlertSheet(
            title: Text("Uninstall the System Helper?", comment: "Title of the alert before uninstalling the helper."),
            message: Text(
                "Relente can't create installers without it. You can install it again at any time.",
                comment: "Message of the alert before uninstalling the helper."),
            action: Text("Uninstall", comment: "Alert button: uninstall the system helper."),
            safeChoice: Text("Cancel", comment: "Alert button: keep the system helper."),
            onAction: onUninstall,
            onSafeChoice: onCancel)
    }
}

#Preview {
    UninstallHelperSheet(onUninstall: {}, onCancel: {})
}
