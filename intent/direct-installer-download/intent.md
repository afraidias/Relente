# Direct installer download — intent

Revision: 1 · State: Accepted
Related issue: N/A — no dedicated issue verified during conversion; roadmap step 9.
Approval: Afraidias, 2026-11-02, revision 1 — explicit acceptance in this conversation ("vale").

## Problem and evidence

The previous acquisition implementation delegates downloading to softwareupdate. Its cancellation
investigation did not establish a reliable end to the Apple-managed transfer; stopping the CLI
alone is insufficient. The owner closed that approach and requested a replacement.

Converted from the [existing draft](https://github.com/afraidias/Relente/blob/92a1608cd0f20476b79dab44794b5f718e02292e/specs/012-direct-installer-download/spec.md)
on 2026-11-02. This migration preserves proposed requirements, not evidence of implementation.

## Audience and desired outcome

People creating macOS installation media should be able to obtain an authentic installer from
Apple within Relente, see actual progress and reliably cancel a transfer without leaving a
partial installer selectable. Preserve offline local selection and the existing USB workflow.

## Constraints and non-goals

- Run Relente on Apple silicon with macOS 26.0 or later, per the accepted product policy.
  Project and CI alignment was handled by the separately accepted
  [Apple silicon host change](../../docs/changes/apple-silicon-host/plan.md).
- Keep network transfers in the unprivileged app and use Apple-hosted content.
- Preserve authenticity, disk validation and erase authorization guarantees.
- Never install macOS on the host or begin USB creation merely by downloading.
- Do not add app dependencies, change signing/releases, terminate update services or clean shared
  system caches. A new privileged preparation capability needs an accepted security design.
- Deletion of retained complete installers remains separate work, tracked by
  [issue #39](https://github.com/afraidias/Relente/issues/39).

## Success measures

A real download reports genuine progress and yields the requested verified installer. Confirmed
transfer cancellation waits for the owned task to stop; partial work is not selectable, including
after relaunch. Failures and preparation boundaries are explained accurately. Existing local
selection and reviewed download UI remain usable and accessible. See [design](spec.md) for
acceptance criteria and the [plan](plan.md) for recorded verification and remaining limitations.

## Investigation questions

The original questions concerned catalog identity and compatibility, safe preparation and
authorization boundaries, and permitted Apple origins and redirects. The [design investigation
conclusions](spec.md#investigation-conclusions--2026-11-04) record the accepted pilot answers
and their limitations. No runtime validation on other Macs or versions is claimed.

## Approval record

Accepted by Afraidias on 2026-11-02, revision 1, responding "vale" to the proposed intent:
download an authentic Apple installer, show real progress, reliably cancel without selectable
partial artifacts, and preserve local selection and useful previous UI. Catalog, compatibility
and preparation remain design questions. This accepts intent only, not design or implementation
plan, and does not authorize merge or release publication.
