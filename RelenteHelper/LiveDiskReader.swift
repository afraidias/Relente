//
//  LiveDiskReader.swift
//  RelenteHelper
//
//  Reads a disk from DiskArbitration as it is right now, on the helper's own, never trusting
//  what the app says about it (helper rule 3).
//  Spec: specs/008-system-helper/spec.md
//

import DiskArbitration
import Foundation

nonisolated struct LiveDiskReader: DiskReading {

    func describe(_ bsdName: String) async -> DiskDescription? {
        guard let session = DASessionCreate(kCFAllocatorDefault),
            let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName)
        else { return nil }
        // A disk that isn't connected has no description.
        return DiskDescriber.describe(disk)
    }

    func bootDisks() async -> Set<String> {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return [] }
        return DiskDescriber.bootDisks(session: session)
    }
}
