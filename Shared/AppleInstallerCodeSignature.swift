import Foundation
import Security

nonisolated enum AppleInstallerCodeSignature {
    static func isValid(_ url: URL, validateResources: Bool = true) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess,
            let requirement
        else { return false }
        var flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures)
        if !validateResources { flags.formUnion(SecCSFlags(rawValue: kSecCSDoNotValidateResources)) }
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }
}
