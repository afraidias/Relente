# Package-backed installer provenance — design proposal

Revision: 1 · Direction: Accepted · Detailed design: Draft

## Required guarantee

A downloaded, user-writable app cannot be trusted merely because a package was signed earlier.
The app envelope in the Ventura sample omits resources. A user-owned hash manifest or read-only
file mode cannot prevent that same user from replacing files or the manifest. A read-only mounted
image also does not establish cryptographic provenance of every source byte. The privileged
operation must establish authenticity independently from a stable private snapshot.

## Recommended boundary for review

Retain the original Apple package as the authoritative artifact, with observed product/version/
build and size for selection. The unprivileged app downloads, verifies and may prepare an isolated
candidate to inspect identity and completeness. That candidate is a preview/reusable derived
artifact, not the helper's trusted execution source. The UI must accurately show which artifact
is retained; do not silently change the accepted outcome to a downloaded package needing manual
installation. Completed-app identity/completeness still needs proof before selection.

At the existing administrator-authorized USB operation, the helper would independently copy the
selected package to a fresh private root-owned directory, validate the resulting snapshot's Apple
package identity, prepare directly from that snapshot without executing scripts and verify exact
OS identity and Apple signing of the executable before launch. Never execute the user-writable
preview app as a substitute. Preserve disk fingerprint, authorization and immediate pre-launch
validation. This is a candidate reuse/refinement of the existing package path, not a new generic
helper command or an already accepted change. No networking or installer -pkg execution in helper.

The private directory and all parents/files required for trusted execution must remain protected
from the caller. Verify source/snapshot type and path safety, reject ambiguous package layouts,
validate symlink destinations/permissions, bind selected product identity to the snapshot and
prevent concurrent replacement. A checksum of a file is an integrity measurement, not a substitute
for Apple's package signature or secure ownership. Define active-operation ownership and cleanup
only after every owned preparation process has terminated; no fire-and-forget cancellation.

## Existing code is a starting point, not proof

Read-only review at continuity HEAD 74b406e:

- Shared/InstallerPackagePreparer.swift copies a package to a private temporary directory,
  evaluates pkgutil output and expands through a fixed pkgutil command. When run in the helper,
  it is intended to derive the app in root-owned storage.
- Shared/InstallerPackageOwnershipPolicy.swift and the helper require private root-owned layout.
  The package-backed app resource exception depends on those prerequisites; the executable still
  requires Apple verification. It cannot be granted to this research app on a user-owned image.
- Shared/CreateInstallMediaPipeline.swift currently recognizes signer identity through parsed
  human-readable pkgutil certificate/status text. Production trust policy needs review; do not
  equate matching names with a cryptographic signer constraint.
- The existing preparer links the inner expanded SharedSupport.dmg, whereas the observed Ventura
  script uses the entire package. These different compositions must be validated explicitly.
- The runner prepares a staged package but later passes the incoming package URL to its private
  launch path; provenance checks expect the staged layout. Trace and test the actual paths before
  assuming the package-backed branch is functional. This investigation did not execute it.
- Its command runner waits for process exit, but preparation cancellation is checked between
  blocking commands. It does not yet demonstrate prompt terminal cancellation during expansion.

These are integration questions within the pilot's design, not changes made or authorization to
weaken existing checks. Address affected helper logic only through accepted requirements/plan
and human security review; no physical-disk operation is needed to test preparation.

## Alternatives and owner decision

1. Recommended for further design: keep script-free app preparation for inspection and use the
   independently verified private package snapshot for privileged use. Requires resolving the
   above integration questions, exact identity and extractor containment.
2. Require ordinary full-app resource validation for every downloaded installer: simplest trust
   rule, but the inspected Ventura app cannot qualify. Show such releases unavailable rather than
   silently bypassing the check. Coverage for modern installers remains unknown.
3. Install the package through Apple's installer: runs privileged scripts and brings different
   side effects/cancellation risks. Not the current direction and not authorized by this draft.

Owner accepted the recommended retained-package/private-preparation direction on 2026-11-03,
replying "okey" to the explicit direction-acceptance question in this chat. This covers keeping
the signed Apple package, unprivileged preparation for inspection, and independent private helper
preparation/verification before authorized use. It does not accept the complete feature design,
a specific signer/identity implementation, an implementation plan, merge or release. Do not
implement from this proposal. Next: specify identity, terminal cancellation, containment and
proof/test obligations; bring the complete requirements/design to owner review.


## Extraction boundary clarification — 2026-11-03

The installed sandbox-exec(1) manual marks the tool deprecated and directs apps to App Sandbox.
Do not base the production helper design on an ad hoc sandbox-exec profile. The installed xar
help also warns that xar is no longer actively developed by Apple; avoid introducing a custom
xar-based production verifier/decoder merely because it was useful for bounded research.

For the accepted script-free direction, verify the private package snapshot before handing it
to the fixed system expansion tool. Define reviewed package-layout eligibility, protected
destination parents, unique nonexistent output directory, resource/time bounds, owned child
process termination and explicit no-script behavior. Reject unknown layouts instead of executing
Distribution/scripts or installing through installer. Recheck app link destinations, file types,
permissions, support composition and exact identity before use. These checks reduce risk but
post-extraction path inspection does not retroactively contain writes by a vulnerable extractor.
A space-limited image is not path confinement. The detailed design must explicitly state reliance
on the system extractor processing an authenticated Apple package, or select and verify a
supported isolation design before claiming filesystem containment. No root extraction experiment
was performed. Do not add a new helper command or permanent image lifecycle without accepted
requirements, failure recovery and security review.
