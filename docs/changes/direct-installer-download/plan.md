# Direct installer download — plan

Revision: 1 · State: Draft
Related issue: N/A — no dedicated issue verified during conversion; roadmap step 9.
Approval: Pending — conversion authorization is not acceptance of intent, design or plan.
Implementation state: Not started
PR: N/A — no PR created for this change.

Intent: [intent.md](intent.md) · Design: [spec.md](spec.md)

## Planning status

This is a draft planning skeleton, not an executable accepted implementation plan. Resolve the
intent and design questions and obtain acceptance before completing implementation planning.
Do not implement from the converted draft.

## Ordered preparation checklist

1. Completed: owner accepted intent revision 1 on 2026-11-02, including success measures and host/installer scope.
2. Reconcile the final previous-acquisition branch: identify reusable UI/code, unfinished checks
   and integration dependencies. Preserve useful work without reviving its cancelled approach.
3. Validate metadata, Apple origins, version/build identity and compatibility using official
   documentation and bounded investigation; record evidence and uncertainty in the design.
4. Validate preparation options and their privilege, collision, side-effect and cancellation
   boundaries. Bring any new helper capability to explicit security design review.
5. Review and accept the resulting design and testable acceptance criteria.
6. Complete this plan with affected files, dependencies, implementation tasks, per-task verification,
   failure/recovery handling and applicable Xcode tools; obtain plan acceptance before coding.

## Risks and dependencies

Metadata may not establish compatibility. Preparation may run scripts, require privileges or lack
safe cancellation. Transfers can race cancellation or termination. Partial cleanup must affect
only proven app-owned artifacts. Host target/build alignment is separately pending; no CI,
signing or release changes are authorized by this skeleton.

## Verification and recovery planning

The design lists required logic/security and real-transfer checks. Use existing project signing
and record actual environment and limitations; do not erase disks to validate downloading.
Choose additional Xcode diagnostics according to the implementation and observed risks. Retain
local selection as the recovery path; never claim control of old system-managed transfers.
Detailed verification tasks remain pending the design decisions above.

## Approval record and deviations

Pending. No accepted implementation plan or approved deviations.

## Execution evidence

2026-11-02: source draft converted into these three artifacts with owner authorization. No code,
external issues, original spec, project or CI configuration changed. No implementation tests or
live downloads performed. Intent, design and plan acceptance remain pending.

2026-11-02: started feature/direct-installer-download from integrated main at 20d5d23 in the
migration worktree, leaving the separate acquisition checkout unchanged. Owner accepted intent
revision 1 ("vale"); design and plan remain Draft/unaccepted. Initial official-source findings
are recorded in spec.md. Next: resolve metadata/compatibility and preparation options, assess
reuse from PR #44, then present design decisions. No source/project/CI changes or live transfer.
