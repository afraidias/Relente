//
//  main.swift
//  RelenteHelper
//
//  The system helper: runs as root, started by launchd when the app connects to its Mach service.
//  It only erases USB drives and SD cards the user confirmed, after its own checks; no shell, no
//  networking, logging through `os_log` (helper rules 1–6).
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
logger.info("Helper started, protocol version \(HelperIdentity.protocolVersion, privacy: .public)")

LiveAuthorizationChecker.installRight()

let delegate = HelperListener(
    pipeline: FormatPipeline(
        authorization: LiveAuthorizationChecker(), disks: LiveDiskReader(), formatter: LiveDiskFormatter()))
let listener = NSXPCListener(machServiceName: HelperIdentity.machServiceName)
// Only the Relente app signed by the team may connect (helper rule 2).
listener.setConnectionCodeSigningRequirement(CodeSigningRequirement.app)
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
