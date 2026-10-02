//
//  SharedArtworkTests.swift
//  RelenteTests
//
//  Which artwork flies between two screens, and which stays with its screen because the other one
//  has no place for it.
//  Spec: specs/007-real-detection/spec.md ("Many installers or drives")
//

import Testing

@testable import Relente

struct SharedArtworkTests {

    @Test func `the drive stays with its screen between Installer and USB Drive`() {
        #expect(SharedArtwork.stayingWithScreens(from: .installer, to: .drive) == [.drive])
        #expect(SharedArtwork.stayingWithScreens(from: .drive, to: .installer) == [.drive])
    }

    @Test func `between screens that both show them, the drive and the installer fly`() {
        #expect(SharedArtwork.stayingWithScreens(from: .drive, to: .review).isEmpty)
        #expect(SharedArtwork.stayingWithScreens(from: .review, to: .creating).isEmpty)
        #expect(SharedArtwork.stayingWithScreens(from: .creating, to: .done).isEmpty)
    }

    @Test func `starting over from Done or Error, nothing flies: both fade with their screens`() {
        #expect(SharedArtwork.stayingWithScreens(from: .done, to: .installer) == [.drive, .installer])
        #expect(SharedArtwork.stayingWithScreens(from: .creating, to: .installer) == [.drive, .installer])
    }

    @Test func `going back from USB Drive, the installer still flies to its tile`() {
        #expect(!SharedArtwork.stayingWithScreens(from: .drive, to: .installer).contains(.installer))
    }
}
