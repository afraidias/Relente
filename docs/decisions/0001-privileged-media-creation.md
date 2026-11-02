# Privileged media creation boundaries

Status: Accepted existing architecture, consolidated 2026-10-29. This records the implementation
on main at `1b06a9a`; it introduces no security exception or behavior change.

## Decision and rationale

Use an unprivileged SwiftUI app and a root helper with a minimal typed XPC API. The helper repeats
validation at execution time: whole external removable disk, boot-disk exclusion, size boundaries,
physical fingerprint and fresh administrator authorization. A disk without media UUID or serial
is refused; size alone cannot distinguish a replacement. The current reasonable-size limits are
8 GB through 2 TB. See SECURITY.md and the security tests for the enforced policy.

Validate the installer and createinstallmedia against Apple's trust anchor. Mount images read-only.
Prepare InstallAssistant packages from a validated root-owned copy in a private directory without
running installer scripts. For that extraction only, an obsolete app resource envelope may be
omitted while signed code and createinstallmedia validation remain required. Direct app/image
sources do not inherit that exception. Preserve the current tests; changing this policy requires
new owner review, not merely editing this ADR.

Root and administrator authorization do not imply removable-volume TCC access. The helper's write
preflight gates erasure; Full Disk Access guidance reflects this architecture's observed behavior.
An app-side probe is insufficient. Supported-OS validation remains in release-readiness.md.

Fresh Service Management registration uses the current in-bundle helper identity. Do not revert
to stale registrations or reset system-wide background items as a recovery shortcut. The code
signing identifier is distinct from the Mach service identity.

## Consequences

No shell, arbitrary command API or networking in the helper. Preserve mutually validated signing,
fixed executable paths and array arguments. Authorization Services owns the system authentication
dialog; the app's Touch ID indicator is not an authorization boundary. Updates and recovery must
keep app and helper compatible. Documentation and process changes never authorize real erasure.
