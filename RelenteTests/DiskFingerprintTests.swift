//
//  DiskFingerprintTests.swift
//  RelenteTests
//

import Testing

@testable import Relente

struct DiskFingerprintTests {

    private let fingerprint = DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "123", size: 32_000_000_000)

    @Test func `the same fingerprint matches`() {
        #expect(fingerprint.matches(fingerprint))
    }

    @Test func `any part that differs doesn't match`() {
        #expect(!fingerprint.matches(DiskFingerprint(mediaUUID: "UUID-5", serialNumber: "123", size: 32_000_000_000)))
        #expect(!fingerprint.matches(DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "124", size: 32_000_000_000)))
        #expect(!fingerprint.matches(DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "123", size: 1)))
        #expect(!fingerprint.matches(DiskFingerprint(mediaUUID: nil, serialNumber: "123", size: 32_000_000_000)))
    }

    @Test func `media UUIDs compare regardless of case`() {
        let lower = DiskFingerprint(mediaUUID: "uuid-4", serialNumber: "123", size: 32_000_000_000)
        #expect(fingerprint.matches(lower))
    }

    @Test func `a media UUID or a serial number makes a drive identifiable`() {
        #expect(fingerprint.isIdentifiable)
        #expect(DiskFingerprint(mediaUUID: "UUID-4", serialNumber: nil, size: 1).isIdentifiable)
        #expect(DiskFingerprint(mediaUUID: nil, serialNumber: "123", size: 1).isIdentifiable)
    }

    @Test func `only its size doesn't identify a drive, so it never matches`() {
        let anonymous = DiskFingerprint(mediaUUID: nil, serialNumber: nil, size: 32_000_000_000)
        #expect(!anonymous.isIdentifiable)
        #expect(!anonymous.matches(anonymous))
        #expect(!DiskFingerprint(mediaUUID: "", serialNumber: " ", size: 1).isIdentifiable)
    }
}
