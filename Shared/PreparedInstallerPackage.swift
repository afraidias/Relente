import Foundation

nonisolated struct PreparedInstallerPackage: Sendable {
    let appURL: URL
    let packageURL: URL
    let temporaryDirectory: URL

    func remove() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}
