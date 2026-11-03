import Foundation

/// Policy for the actual signer chain reported by a successful system pkgutil check.
/// Never call this on untrusted XAR certificate elements or on a failed command's output.
nonisolated enum AppleInstallerPackageSignature {
    // Apple PKI certificates, independently fetched and compared during design research.
    static let softwareUpdateCA = "1299e9bfe776a29ff452f8c4f5e55f3b4dfd2934349dd1850b8274f35c71745c"
    static let appleRoot = "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024"

    static func acceptsSuccessfulCheck(_ output: String) -> Bool {
        guard output.utf8.count <= 65_536 else { return false }
        let lines = output.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard lines.filter({ $0.hasPrefix("Status:") }) == ["Status: signed Apple Software"],
            lines.filter({ $0 == "Certificate Chain:" }).count == 1
        else { return false }
        var certificates: [(name: String, fingerprint: String)] = []
        var readingFingerprint = false
        for line in lines {
            if line.range(of: "^[0-9]+\\. ", options: .regularExpression) != nil {
                certificates.append((line, ""))
                readingFingerprint = false
            } else if line == "SHA256 Fingerprint:" {
                guard let last = certificates.last, last.fingerprint.isEmpty, !readingFingerprint else { return false }
                readingFingerprint = true
            } else if readingFingerprint {
                let bytes = line.split(whereSeparator: \.isWhitespace)
                if !bytes.isEmpty
                    && bytes.allSatisfy({ token in
                        token.count == 2 && token.allSatisfy { $0.isASCII && $0.isHexDigit }
                    })
                {
                    let i = certificates.count - 1
                    certificates[i].fingerprint += bytes.joined().lowercased()
                    guard certificates[i].fingerprint.count <= 64 else { return false }
                } else {
                    readingFingerprint = false
                }
            }
        }
        guard certificates.count == 3,
            certificates[0].name == "1. Software Update", certificates[0].fingerprint.count == 64,
            certificates[1].name == "2. Apple Software Update Certification Authority",
            certificates[2].name == "3. Apple Root CA"
        else { return false }
        return certificates[1].fingerprint == softwareUpdateCA && certificates[2].fingerprint == appleRoot
    }
}
