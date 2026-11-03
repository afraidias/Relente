import Foundation
import Testing

@testable import Relente

struct AvailableInstallerTests {
    private let selected = AvailableInstaller(title: "macOS Ventura", version: "13.7.8", build: "22H730")

    @Test func unknownBuildDoesNotReuseALocalInstaller() {
        let local = InstallerSource(
            url: URL(filePath: "/sample.app"), name: "macOS Ventura",
            version: "13.7.8", kind: .app, size: 1)
        #expect(selected.localMatch(in: [local]) == .none)
    }

    @Test func exactBuildReusesOnlyAnUnambiguousLocalInstaller() {
        let local = InstallerSource(
            url: URL(filePath: "/sample.app"), name: "macOS Ventura",
            version: "13.7.8", kind: .app, size: 1, build: "22H730")
        #expect(selected.localMatch(in: [local]) == .unique(local))
        let other = InstallerSource(
            url: URL(filePath: "/other.app"), name: local.name,
            version: local.version, kind: .app, size: 1, build: local.build)
        #expect(selected.localMatch(in: [local, other]) == .ambiguous)
        #expect(
            AvailableInstaller(title: selected.title, version: selected.version, build: nil)
                .localMatch(in: [local]) == .none)
    }
    @Test func latestEligibleVersionIsUniquePerFamily() {
        let old = AvailableInstaller(title: "macOS Ventura", version: "13.6", build: "22G120")
        let other = AvailableInstaller(title: "macOS Sonoma", version: "14.7", build: "23H100")
        #expect(AvailableInstaller.latestPerFamily([old, other, selected]) == [other, selected])
        let ambiguous = AvailableInstaller(title: selected.title, version: selected.version, build: "22H731")
        #expect(AvailableInstaller.latestPerFamily([old, selected, ambiguous, other]) == [other])
        let unknown = AvailableInstaller(title: "macOS Ventura", version: "13.8", build: nil)
        #expect(AvailableInstaller.latestPerFamily([selected, unknown, other]) == [other])
    }

}
