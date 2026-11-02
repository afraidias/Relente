# Design: AI-native SDLC migration

Revision: 1 · State: Accepted · [Intent](intent.md) · Issue: N/A — repository process migration.

## Requirements and acceptance

- Use six lifecycle stages, with accepted intent, requirements/design and implementation plan.
- Keep tasks inside plan.md and record approvals, revisions, deviations and actual evidence.
- Share AGENTS.md and project skills between both agents; replace the personal Claude entrypoint
  without publishing private content. Preserve local skill attribution and licenses.
- Retain product behavior, decisions and unresolved roadmap work before deleting old artifacts.
- Distinguish advisory instructions from actual permissions, hooks and CI enforcement.
- Allow commits, branch pushes and PR creation within approved work; require owner review and
  approval for merge, release publication and critical security decisions. Describe release/recovery and
  maintenance without claiming autonomous paid infrastructure is active.

## Changes to existing behavior and edge cases

Only the development process changes. Source edits remove stale documentation comments only.
Historical changelog entries stay untouched. The owner accepted integrating the validated
migration before successor installer acquisition, superseding the original sequencing constraint.
Preserve the acquisition branch and its unfinished work; do not merge its unverified download
mechanism as a completed feature. Existing local instructions in that checkout stay untouched.
The successor change reviews and reuses useful UI/code under the new lifecycle. Merge still
requires owner review and approval.

## Decisions and concerns

Git is the history, not an archive folder. AGENTS.md is authoritative; CLAUDE.md imports it.
Codex skill symlinks expose the maintained Claude skill sources without copies. Runtime discovery
must be verified separately from static path checks. New artifacts remain as the future audit
trail. Native permission coverage varies by runtime; no new universal approval hook is claimed.
No product UI is changed, so this migration introduces no new HIG exception.

Deferred work: final acquisition reconciliation and pilot are in [plan.md](plan.md).
Release/runtime deferrals are in [release readiness](../../release-readiness.md).

## Approval

Accepted by the project owner (Afraidias), 2026-10-29, revision 1, in this chat: "PLEASE IMPLEMENT
THIS PLAN: Migración completa al AI-native SDLC", including the complete plan reproduced in that
message. This is a consolidated migration approval; it does not claim separate earlier artifact
sign-offs. At that time, Git publication was not authorized. The later owner-approved rule
supersedes that restriction for commits, work-branch pushes and PR creation within accepted scope;
merge still requires owner review and approval, and release publication remains separately authorized.
See the chronological amendments and current pending work in [plan.md](plan.md).
