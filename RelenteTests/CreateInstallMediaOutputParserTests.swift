import Foundation
import Testing

@testable import Relente

struct CreateInstallMediaOutputParserTests {

    @Test func `parses erase and copy percentages`() {
        #expect(
            CreateInstallMediaOutputParser.progress(in: "Erasing disk: 40%...")
                == .init(phase: .erase, fraction: 0.4))
        #expect(
            CreateInstallMediaOutputParser.progress(in: "Copying to disk: 72%...")
                == .init(phase: .copy, fraction: 0.72))
    }

    @Test func `recognizes the start of copying before Apple reports a percentage`() {
        #expect(
            CreateInstallMediaOutputParser.progress(in: "Copying essential files...")
                == .init(phase: .copy, fraction: nil))
    }

    @Test func `keeps phases indeterminate when there is no percentage`() {
        #expect(
            CreateInstallMediaOutputParser.progress(in: "Making disk bootable...")
                == .init(phase: .makeBootable, fraction: nil))
    }

    @Test func `unknown output is ignored and invalid percentages stay indeterminate`() {
        #expect(CreateInstallMediaOutputParser.progress(in: "Install media now available") == nil)
        #expect(
            CreateInstallMediaOutputParser.progress(in: "Copying to disk: 120%")
                == .init(phase: .copy, fraction: nil))
    }

    @Test func `unrecognized output does not imply completion`() {
        #expect(CreateInstallMediaOutputParser.progress(in: "some new Apple output") == nil)
    }

    @Test func `finds progress after a large output line`() {
        let line = String(repeating: "output ", count: 20_000) + "Copying to disk: 55%..."
        #expect(CreateInstallMediaOutputParser.progress(in: line) == .init(phase: .copy, fraction: 0.55))
    }

    @Test func `reads the available installer volume only from Apple's completion line`() {
        #expect(
            CreateInstallMediaOutputParser.availableVolume(
                in: "Install media now available at \"/Volumes/Install macOS Tahoe\"")
                == URL(filePath: "/Volumes/Install macOS Tahoe", directoryHint: .isDirectory))
        #expect(
            CreateInstallMediaOutputParser.availableVolume(in: "Install media now available at /tmp/USB")
                == URL(filePath: "/tmp/USB", directoryHint: .isDirectory))
        #expect(CreateInstallMediaOutputParser.availableVolume(in: "Install media now available at relative") == nil)
    }
}
