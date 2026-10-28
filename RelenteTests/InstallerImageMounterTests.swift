import Foundation
import Testing

@testable import Relente

struct InstallerImageMounterTests {

    @Test func `reuses a matching existing mount without taking ownership`() throws {
        let image = URL(filePath: "/private/tmp/Installer.dmg")
        let info = try propertyList([
            "images": [
                [
                    "image-path": image.path,
                    "system-entities": [
                        ["dev-entry": "/dev/disk4s1", "mount-point": "/Volumes/Installer"]
                    ],
                ]
            ]
        ])
        let commands = FakeImageCommands(info: info)

        let mount = InstallerImageMounter.mount(image, run: commands.run)

        #expect(mount?.url == URL(filePath: "/Volumes/Installer"))
        #expect(mount?.device == nil)
        #expect(mount?.isOwned == false)
        #expect(commands.calls.count == 1)
        #expect(commands.calls[0].0 == "/usr/bin/hdiutil")
        #expect(commands.calls[0].1 == ["info", "-plist"])
    }

    @Test func `attaches an unmounted image read only and without browsing`() throws {
        let image = URL(filePath: "/private/tmp/Installer.dmg")
        let attached = try propertyList([
            "system-entities": [
                ["dev-entry": "/dev/disk5s1", "mount-point": "/Volumes/Relente Installer"]
            ]
        ])
        let commands = FakeImageCommands(info: try propertyList(["images": []]), attach: attached)

        let mount = InstallerImageMounter.mount(image, run: commands.run)

        #expect(mount?.url == URL(filePath: "/Volumes/Relente Installer"))
        #expect(mount?.device == "/dev/disk5s1")
        #expect(mount?.isOwned == true)
        #expect(commands.calls.count == 2)
        #expect(commands.calls[0].0 == "/usr/bin/hdiutil")
        #expect(commands.calls[0].1 == ["info", "-plist"])
        #expect(commands.calls[1].0 == "/usr/bin/hdiutil")
        #expect(commands.calls[1].1 == ["attach", "-readonly", "-nobrowse", "-plist", image.path])
    }

    @Test func `detaches only a mount owned by this operation`() {
        let owned = InstallerImageMount(url: URL(filePath: "/Volumes/Installer"), device: "/dev/disk5", isOwned: true)
        let existing = InstallerImageMount(
            url: URL(filePath: "/Volumes/Existing"), device: nil, isOwned: false)
        let commands = FakeImageCommands(info: nil)

        InstallerImageMounter.detach(owned, run: commands.run)
        InstallerImageMounter.detach(existing, run: commands.run)

        #expect(commands.calls.count == 1)
        #expect(commands.calls[0].0 == "/usr/bin/hdiutil")
        #expect(commands.calls[0].1 == ["detach", "/dev/disk5"])
    }

    @Test func `owned image mount is detached after every terminal result`() async {
        let owned = InstallerImageMount(url: URL(filePath: "/Volumes/Installer"), device: "/dev/disk5", isOwned: true)
        let commands = FakeImageCommands(info: nil)
        let terminalResults = [0, -1, 130]

        for terminalResult in terminalResults {
            let result = await InstallerImageMounter.withCleanup(of: owned, run: commands.run) { terminalResult }
            #expect(result == terminalResult)
        }

        let expectedDetachCalls = [
            ["detach", "/dev/disk5"],
            ["detach", "/dev/disk5"],
            ["detach", "/dev/disk5"],
        ]
        #expect(commands.calls.map(\.1) == expectedDetachCalls)
    }

    private func propertyList(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    }
}

private final class FakeImageCommands: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var recordedCalls: [(String, [String])] = []
    private let info: Data?
    private let attach: Data?

    init(info: Data?, attach: Data? = nil) {
        self.info = info
        self.attach = attach
    }

    var calls: [(String, [String])] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    nonisolated func run(_ executable: String, _ arguments: [String]) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        recordedCalls.append((executable, arguments))
        switch arguments.first {
        case "info": return info
        case "attach": return attach
        case "detach": return Data()
        default: return nil
        }
    }
}
