# Release verification and recovery

This runbook describes the process; it does not authorize release publication. Signing and release
configuration changes follow the accepted design and implementation plan; reading this runbook
alone does not approve such a change.
The first distributed release remains gated by [release readiness](release-readiness.md).

## Before publishing

Obtain owner authorization and review the diff, accepted change artifacts and security findings.
Confirm all existing required CI checks pass, including the arm64 Release build. Record the exact commit/tag, build tools, actual architectures and deployment target,
test results and manual supported-Mac evidence. Check these against the
[approved support policy](product.md#supported-macs): Apple silicon and macOS 26.0 or later.
Verify the
actual distributed bundle's Developer ID signatures, notarization and Gatekeeper acceptance, not
only an unsigned CI build. Check helper registration, mutual signing checks, fresh authorization,
permission preflight, uninstall and sample-data UI behavior. Any real erase needs its own explicit
owner authorization and a disposable, confirmed destination; it is never a release script step.

Review user-facing changes, known limitations and recovery instructions. Signing keys and
notarization credentials stay outside the repository. Existing release-please settings remain the
version authority; version/configuration changes need the approvals in AGENTS.md.

## After publishing

Record the published artifact and version, inspect installation/startup reports and triage failures.
A regression returns to Plan as an issue and intent. No agent is monitoring releases automatically.

## Faulty release

Ask the owner before withdrawing an artifact, publishing a warning or releasing a correction.
Record the affected versions, impact and safe alternative. Stop recommending an unsafe build;
point users to a previously validated release only when compatible with their app/helper state.
Prefer a forward fix if downgrading would leave an incompatible privileged helper. Verify the
app/helper pair and supported macOS versions before offering recovery steps. Never reset global
Service Management state, bypass signatures or weaken authorization to make a downgrade work.

Replacing or reverting Relente repairs application behavior only. It cannot restore files erased
from a USB drive or SD card. Do not promise data recovery or automatically retry a destructive
operation after a failure. Existing created media and interrupted media require separate diagnosis.
