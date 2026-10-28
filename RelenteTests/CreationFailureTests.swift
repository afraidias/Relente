//
//  CreationFailureTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct CreationFailureTests {

    /// The text in English, whatever the language of the Mac running the tests.
    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    private func spanish(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "es_ES")
        return String(localized: resource)
    }

    // MARK: - Reasons

    @Test(arguments: CreationFailure.Reason.allCases)
    func `every reason has a title and a recovery line`(reason: CreationFailure.Reason) {
        #expect(!english(reason.title).isEmpty)
        #expect(!english(reason.recovery).isEmpty)
    }

    @Test func `new helper failures have the specified English and Spanish copy`() {
        let cases: [(CreationFailure.Reason, String, String, String, String)] = [
            (
                .driveChanged, "The drive changed after you confirmed it.",
                "Check it's the right drive and choose it again.", "La memoria ha cambiado después de confirmarla.",
                "Comprueba que es la memoria correcta y vuelve a elegirla."
            ),
            (
                .driveNotAllowed, "Relente can only erase USB drives and SD cards.", "Use a different drive.",
                "Relente solo puede borrar memorias USB y tarjetas SD.", "Usa otra memoria."
            ),
            (
                .formatFailed, "The drive couldn't be erased.", "Try again, or use a different drive.",
                "No se ha podido borrar la memoria.", "Inténtalo de nuevo o usa otra memoria."
            ),
            (
                .volumeAccessDenied, "macOS prevented writing to the drive.",
                "Enable Full Disk Access for Relente in Privacy & Security, then try again. The drive may have been erased.",
                "macOS ha impedido escribir en la memoria.",
                "Activa el Acceso total al disco para Relente en Privacidad y seguridad y vuelve a intentarlo. Puede que la unidad se haya borrado."
            ),
            (
                .helperUnavailable, "The system helper didn't respond.",
                "Try again. If it keeps happening, quit and open Relente again.",
                "El ayudante del sistema no ha respondido.",
                "Vuelve a intentarlo. Si sigue pasando, cierra Relente y vuelve a abrirlo."
            ),
        ]

        for (reason, title, recovery, spanishTitle, spanishRecovery) in cases {
            #expect(english(reason.title) == title)
            #expect(english(reason.recovery) == recovery)
            #expect(spanish(reason.title) == spanishTitle)
            #expect(spanish(reason.recovery) == spanishRecovery)
        }
    }

    @Test func `a disconnected drive says so and what to do`() {
        #expect(english(CreationFailure.Reason.driveDisconnected.title) == "The drive was disconnected.")
        #expect(english(CreationFailure.Reason.driveDisconnected.recovery) == "Plug it in again and try again.")
    }

    // MARK: - Where it stopped

    @Test func `STOPPED AT comes from the progress when it stopped`() {
        let failure = CreationFailure(reason: .driveDisconnected, progress: .sampleMidCopy)
        #expect(failure.stoppedPercent == CreationProgress.sampleMidCopy.percent)
    }

    @Test func `a failure during Format stops at 5 % at most`() {
        let failure = CreationFailure(reason: .unknown, progress: CreationProgress(phase: .format, phaseFraction: 1))
        #expect(failure.stoppedPercent <= 5)
    }

    @Test func `a failure at the very start stops at 0 %`() {
        let failure = CreationFailure(reason: .unknown, progress: CreationProgress(phase: .format, phaseFraction: 0))
        #expect(failure.stoppedPercent == 0)
    }

    // MARK: - State

    @Test func `the state gives the progress to draw, running or failed`() {
        let running = CreationState.running(.sampleMidCopy)
        #expect(running.progress == .sampleMidCopy)
        #expect(running.failure == nil)

        let failed = CreationState.failed(.sampleDriveDisconnected)
        #expect(failed.progress == CreationFailure.sampleDriveDisconnected.progress)
        #expect(failed.failure == .sampleDriveDisconnected)
    }

    @Test func `samples are a disconnected drive and a cancellation`() {
        #expect(CreationFailure.sampleDriveDisconnected.reason == .driveDisconnected)
        #expect(CreationFailure.sampleCancelled.reason == .cancelled)
    }
}
