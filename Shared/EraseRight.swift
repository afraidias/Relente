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

    /// An administrator authenticates every time: not shared with other rights or processes, and
    /// never reused (no timeout).
    static var rule: [String: Any] {
        [
            "class": "user",
            "group": "admin",
            "shared": false,
            "timeout": 0,
            "allow-root": false,
            "session-owner": false,
            "authenticate-user": true,
            "version": 1,
        ]
    }
}
