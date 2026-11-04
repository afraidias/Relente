# Intent

Revision 1 · Accepted\
Issue: N/A (owner-directed platform alignment)\
Approval: project owner, 2026-11-04, revision 1, conversation: “acepto” in the separate Apple silicon host alignment task.

## Problem

Relente's approved host support is Apple silicon running macOS 26.0 or later, but the project still
builds universal app and helper binaries and declares macOS 14.0. CI asserts both architectures
without checking the minimum OS. The mismatch makes the shipped artifact and its verification
broader and older than the supported platform policy.

## Audience and outcome

People building and running Relente should receive an arm64 app and helper that require macOS 26.0
or later, matching the existing support policy.

## Constraints and non-goals

- Preserve Intel as a supported architecture for Macs that start from media created by Relente.
- Do not broaden this work into installer compatibility or UI fallback cleanup.
- Do not change signing, release publication or helper security behavior.
- Do not run installer downloads or real installation media creation.

## Success measures

The effective Release app and helper build settings and produced binaries are arm64 with minimum
macOS 26.0. CI enforces architecture, deployment target and helper plist presence. Active support
documentation agrees with those settings and the approved host policy.

## Open questions

None.
