import Testing

@testable import Relente

struct SoftwareUpdateOutputParserTests {

    @Test func `reads versions and builds from full installer listings`() throws {
        let output = """
            Finding available software
            Software Update found the following full installers:
            * Title: macOS Sequoia, Version: 15.6, Size: 15.0GB, Build: 24G84, Deferred: NO
              Title: macOS Tahoe, Version: 26.0, Size: 16.5GB, Build: 25A354, Deferred: NO
            """

        let installers = try SoftwareUpdateOutputParser.fullInstallers(from: output)

        #expect(installers.map(\.version) == ["26.0", "15.6"])
        #expect(installers.map(\.title) == ["macOS Tahoe", "macOS Sequoia"])
        #expect(installers.map(\.build) == ["25A354", "24G84"])
    }

    @Test func `a missing build remains unknown`() throws {
        let output = "Title: macOS Sequoia, Version: 15.6, Size: 15.0GB"

        let installers = try SoftwareUpdateOutputParser.fullInstallers(from: output)

        #expect(installers.count == 1)
        #expect(installers[0].build == nil)
    }

    @Test func `an empty catalog is a valid empty list`() throws {
        let output = "Software Update found the following full installers:"

        #expect(try SoftwareUpdateOutputParser.fullInstallers(from: output).isEmpty)
    }

    @Test func `a catalog entry without a usable version fails closed`() {
        let output = "Title: macOS Sequoia, Version: unknown, Build: 24G84"

        #expect(throws: SoftwareUpdateOutputParser.ParseError.self) {
            try SoftwareUpdateOutputParser.fullInstallers(from: output)
        }
    }

    @Test func `progress is returned only when the command reports a valid percentage`() {
        #expect(SoftwareUpdateOutputParser.reportedProgress(in: "Installing: 12.5%") == 0.125)
        #expect(SoftwareUpdateOutputParser.reportedProgress(in: "Downloading: 100%") == 1)
        #expect(SoftwareUpdateOutputParser.reportedProgress(in: "Scanning for installer") == nil)
        #expect(SoftwareUpdateOutputParser.reportedProgress(in: "Installing: 101%") == nil)
    }
}
