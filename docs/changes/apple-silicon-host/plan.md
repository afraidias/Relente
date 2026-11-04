# Implementation plan

Revision 1 · Accepted\
Design: [spec.md](spec.md)\
Issue: N/A (owner-directed platform alignment)\
PR: Pending\
Implementation: Verified\
Approval: project owner, 2026-11-04, revision 1, conversation: “acepto” after plan review.

## Approach

Make the minimum build-setting and CI assertion changes, then reconcile active documentation to the
accepted platform policy. Keep changes in this branch and review the diff against the accepted
intent and design.

## Tasks and acceptance

1. Set macOS deployment target to 26.0 and architecture to arm64 for app and helper configurations.
   Acceptance: `xcodebuild -showBuildSettings` reports the intended effective values for both targets.
2. Update CI's Release build checks to require exactly arm64 and minimum macOS 26.0, preserving the
   helper launchd plist check. Acceptance: workflow logic fails if either binary contains x86_64,
   lacks arm64, has a different minimum, or lacks the plist.
3. Reconcile README, BUILDING, AGENTS.md, product support policy and release runbook. Acceptance:
   descriptions agree with the configuration; Intel destination boot guidance stays intact.
4. Verify using Xcode GUI, inspect effective settings and produced bundle, run tests, strict full Swift lint, and doc/link checks. Acceptance: results and limits are recorded below.

## Risks and recovery

The older OS requirement intentionally prevents launch on macOS versions before 26.0. The existing
fallback code remains compile-checked. If project integration uncovers an unexpected compatibility
dependency, stop and return the design to owner review before changing scope. Reverting the build
setting and CI/doc changes restores the prior build behavior.

## Execution evidence

- Xcode 27.1, on macOS 27.2 Apple silicon: project and helper Release effective settings resolve to `ARCHS = arm64` and `MACOSX_DEPLOYMENT_TARGET = 26.0`.
- Xcode GUI build from this worktree succeeded after `InstallerView` began explicitly discarding the drop handler's return value. Xcode test navigator reports 370 tests Passed; the test console reports 27 XCTest tests with 0 failures in 367.196 seconds. No real drive operations were performed.
- The Xcode-produced Debug app and embedded helper are both arm64; the app plist reports `LSMinimumSystemVersion` 26.0.
- Full strict Swift lint and `git diff --check` pass.
- Xcode Product → Build For → Profiling completed successfully after a Clean Build Folder and again after the final project-setting change (12:30). A clean Release `xcodebuild` completed successfully outside the restricted shell, generated `AppIcon.icns` from the existing `AppIcon.icon`, and produced arm64-only app and helper binaries. Both checked bundles contain only arm64; the app plist reports `LSMinimumSystemVersion` 26.0; the embedded launchd plist passes `plutil -lint`.
- The Xcode 27.1 App Intents metadata phase warned that no `AppIntents.framework` dependency was found even though the app has no App Intents. Weak-linking the system framework in the app target's Debug and Release configurations removes that warning; a clean Release build now reports only “Extracted no relevant App Intents symbols, skipping writing output.”
- The earlier standalone `actool` failure was specific to running the compiler in the restricted shell: even a newly saved Icon Composer document failed there, while the same project built successfully through Xcode and through `xcodebuild` with the required Xcode services available. The tracked icon source was left unchanged; regeneration was unnecessary.
- CI execution remains pending the PR.
