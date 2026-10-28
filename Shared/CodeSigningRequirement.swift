//
//  CodeSigningRequirement.swift
//  Relente
//
//  Who may be at the other end of the XPC connection (helper rule 2): the helper accepts only the
//  Relente app, and the app talks only to the Relente helper, both signed by the same team.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated enum CodeSigningRequirement {
    /// The team that signs Relente (Apple Development or Developer ID certificates).
    static let teamID = "99TLZFAX53"
    static let appIdentifier = "com.afraidias.Relente"

    /// What the helper requires of the app connecting to it.
    static let app = requirement(identifier: appIdentifier)
    /// What the app requires of the helper it connects to.
    static let helper = requirement(identifier: HelperIdentity.bundleIdentifier)

    /// Signed with this identifier by a certificate Apple issued to the team.
    private static func requirement(identifier: String) -> String {
        #"identifier "\#(identifier)" and anchor apple generic and certificate leaf[subject.OU] = "\#(teamID)""#
    }
}
