import Foundation

nonisolated struct PreparedInstallerPackage: Sendable {
    let appURL: URL
    let packageURL: URL
    let temporaryDirectory: URL

    @discardableResult
    func remove() -> Bool {
        do {
            try FileManager.default.removeItem(at: temporaryDirectory)
            return true
        } catch { return false }
    }
}
