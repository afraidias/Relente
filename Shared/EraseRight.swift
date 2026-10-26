//
//  EraseRight.swift
//  Relente
//
//  The Authorization Services right every erase needs (helper rule 5). The helper adds it to the
//  authorization database; the app asks for it (macOS shows its dialog); the helper checks it
//  again before doing anything.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated enum EraseRight {
    static let name = "com.afraidias.Relente.erase"

    /// macOS's own rule for this: an administrator authenticates, and the credential isn't shared
    /// with other authorizations and lasts 30 s, long enough for the helper to check it. The app
    /// makes a new authorization for each erase and destroys it afterwards, so every erase asks.
    /// (Version 1 had a rule of its own with no timeout, which expired before the helper's check.)
    static let delegatedRule = "authenticate-admin-nonshared"

    /// The right's definition. `version` changes whenever it does, so the helper updates it.
    static var rule: [String: Any] {
        [
            "class": "rule",
            "rule": [delegatedRule],
            "version": 2,
        ]
    }
}
