# Requirements and design

Revision 1 · Accepted\
Intent: [intent.md](intent.md)\
Issue: N/A (owner-directed platform alignment)\
Approval: project owner, 2026-11-04, revision 1, conversation: “acepto” in the separate Apple silicon host alignment task.

## Requirements

1. Set the app and helper minimum deployment target to macOS 26.0 in project build settings.
2. Produce arm64-only app and helper binaries for Release; do not build x86_64 slices.
3. Update CI to assert arm64-only binaries, minimum system version 26.0, and the embedded helper launchd plist.
4. Reconcile active support and build documentation, including README, BUILDING, AGENTS.md and release guidance, with the approved policy and actual build.
5. Preserve Intel startup instructions for created media, which concern destination Macs rather than Macs running Relente.

## Acceptance criteria

- Xcode's effective Release settings resolve to arm64 and macOS 26.0 for both app and helper.
- A Release build completes; both executable slices are exactly arm64 and the app bundle reports minimum system 26.0.
- CI contains explicit failing checks for those properties and for the helper plist.
- Documentation contains no claim that Relente's host build remains universal or targets macOS 14.
- Existing classic control fallbacks and previews remain as code; they do not imply supported or tested hosts below macOS 26.
- No installer download, helper installation or real disk operation is performed.

## Verification scope

Run the complete `RelenteTests` unit-test target and `RelenteUITests` with sample data, plus a Release
build and full strict Swift lint. Confirm produced app and helper architecture and `LSMinimumSystemVersion`.
These checks validate compilation and supported product metadata; they do not substitute for a
manual launch on macOS 26.0. CI repeats unit tests, lint and Release assertions. UI tests use sample
services and never erase media. No architecture-specific or macOS 26-only runtime branch is added,
so no new opt-in/live installer tests apply.

## Decisions and boundaries

- Keep Intel boot-card guidance in the Done screen and its tests.
- Retain classic controls as implementation fallbacks; remove misleading claims of old-host support only.
- Do not add an architecture gate to the runtime; the product bundle and documented support target define compatibility.
- No HIG exception or helper security behavior change.

## Changes to existing behavior

Older Intel Macs and Macs below macOS 26 will no longer be able to run the built app. This reflects
the already approved supported-host policy, rather than a change to installer media compatibility.

## Deferred work

None.
