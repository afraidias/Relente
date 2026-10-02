//
//  main.swift
//  RelenteHelper
//
//  The system helper: runs as root, started by launchd when the app connects. For now it only
//  logs that it started; the XPC listener comes with the rest of spec 008.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
logger.info("Helper started (\(HelperIdentity.machServiceName, privacy: .public))")
