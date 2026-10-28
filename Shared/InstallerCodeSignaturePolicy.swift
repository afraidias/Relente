import Foundation

nonisolated enum InstallerCodeSignaturePolicy {
    static func isValid(
        installer: URL, executable: URL, packageBacked: Bool,
        verifyAppleSignature: (URL, Bool) -> Bool
    ) -> Bool {
        guard InstallerPathSafety.isSafe(installer), InstallerPathSafety.isSafe(executable) else { return false }
        return verifyAppleSignature(installer, !packageBacked)
            && verifyAppleSignature(executable, true)
    }
}
