# Installer signature policy investigation — 2026-11-03

Research status: unresolved; no implementation or security-policy change accepted.

## Official contracts

Apple documents [kSecCSStrictValidate](https://developer.apple.com/documentation/security/kseccsstrictvalidate)
as additional bundle-structure/resource-envelope validation. Its
[weak-resource-rules status](https://developer.apple.com/documentation/security/errseccsweakresourcerules)
identifies obsolete resource envelopes with custom omission rules. The installed codesign(1)
manual distinguishes ordinary verification of sealed components from additional strict checks
and notes that signature verification is not an OS-policy/Gatekeeper assessment. Apple's archived
[TN2206](https://developer.apple.com/library/archive/technotes/tn2206/) discusses deprecated custom
resource rules and recursive validation. No installer-specific exception authorizing Relente to
ignore resources was found in this bounded source review. API pages' Markdown retrieval failed
in the web reader; indexed official text and local manual supplied the cited contract details.

## Current Relente code inspected read-only

LiveCreateInstallMediaRunner.hasAppleCodeSignature uses SecStaticCodeCheckValidity with an Apple
anchor requirement and ordinary flags when validateResources is true; it does not opt into
kSecCSStrictValidate. Its package-backed route can omit app-resource checking only when the
existing prepared-package provenance/private root-owned layout policy succeeds; the executable
still receives resource-validating verification. This is an existing specialized path, not proof
that the user-owned research candidate qualifies. No code or rule was changed or exercised.

## Comparative sample result

Reattached the existing research sparsebundle readonly/nobrowse at its owned mountpoint. Returned
image identity disk6, mounted volume disk7s1. Ran codesign --verify with explicit -R '=anchor apple':

| Subject | Additional options | Exit/result |
| --- | --- | --- |
| Candidate app | --deep, no --strict | 1, obsolete resource envelope/custom omit rules |
| Untouched expanded app | --deep, no --strict | 1, same error |
| Candidate app | neither --deep nor --strict | 1, same error |

Therefore the earlier hypothesis that the added strict mode alone caused the failure is disproved
for this sample. Read the untouched app's CodeResources plist as data: both rules and rules2
contain a catch-all omission rule. The app envelope cannot by itself establish integrity of all
bundle resources. Package Apple signature validation and createinstallmedia verification passed
in the prior experiment, but they do not automatically validate every assembled resource.
No resource-omitting verification was substituted as success; no app was launched or selected.

## Design consequence

Do not remove strict flags as a supposed fix. Script-free preparation remains a research option,
but accepting the result needs an explicit provenance/integrity design: retain and validate the
original Apple package, prove the candidate's files/layout derive from its authenticated payload
and the prescribed support composition, prevent modifications between preparation and privileged
use, and independently check the exact executable's Apple signature immediately before execution.
This is a proposed proof obligation, not an implemented or approved alternative verifier. A hash
recorded after assembling unauthenticated files would not supply that proof. User-writable staging
and the existing root-owned prepared-package route have different trust boundaries.

Exact OS identity from completed support metadata, comprehensive resource provenance, safe path
containment and terminal preparation cancellation remain unverified. Do not infer support for
all releases or claim a complete usable installer. Resolve this security design with the owner
before implementation. No extra package download is required for the next design work.


## Public Apple certificate cross-check — 2026-11-03

Apple's [PKI page](https://www.apple.com/certificateauthority/) links its root and Software Update
intermediate. Downloaded those two public DER certificates via HTTPS with normal TLS validation,
no redirects, 20-second timeout and 64 KiB response cap. No keychain modification. Their SHA-256
hashes exactly match the chain reported by the successful pkgutil package check:

- [Apple root](https://www.apple.com/appleca/AppleIncRootCertificate.cer): 1,215 bytes,
  b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024.
- [Software Update CA](https://www.apple.com/certificateauthority/AppleSoftwareUpdateCertificationAuthority.cer):
  1,136 bytes, 1299e9bfe776a29ff452f8c4f5e55f3b4dfd2934349dd1850b8274f35c71745c.

The chain embedded in the package XAR header has the same DER hashes, but that comparison alone
would not prove that a certificate actually signed the package. Keep it distinct from the
successful system package signature/trust evaluation. An attacker-controlled archive could
contain unrelated public certificates. This observation is one known chain, not an exhaustive
list of all Apple installer signing chains or a justified pin to the current leaf certificate.

Proposed verifier design for review: require a successful system package-signature/trust
evaluation and bind its actual signer chain to reviewed Apple root/Software Update intermediate
certificates. Reject ambiguous/incomplete output or unavailable trust evaluation. If the chosen
interface is pkgutil text, use a controlled language environment, verify the fingerprints
reported for the validated chain rather than just display names, and test altered/truncated/
localized output. Confirm the tool's binding and output assumptions during implementation review;
do not infer them from arbitrary embedded X509 elements. Unexpected chain rotation is a visible
unsupported-verification failure, not an automatic fallback to any system-trusted signer.
Maintain certificate policy explicitly and re-review additions. This proposal is not implemented
and still needs acceptance as part of the complete security design.
