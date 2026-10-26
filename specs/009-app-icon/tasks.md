# 009 · App icon — tasks

**Status:** Approved by the owner on 2026-10-26; resources and automated checks complete,
manual verification and spec 008 integration outstanding.

The owner is still working on spec 008 in another chat. Tasks 1–5 can proceed independently
in this checkout after approval; final integration waits for 008.

- [x] Task 1: Prepare the production icon.
  - Acceptance: one outlined B foreground with a transparent open letter, ivory on a full-bleed
    ink-blue Composer fill; approved glass finish, no baked background corners or shadows.
  - Verify: inspect SVG/JSON; export through Icon Composer and compare with the approved preview.
  - Files: `Relente/Resources/AppIcon.icon/Assets/RelenteMark.svg`,
    `Relente/Resources/AppIcon.icon/icon.json`.
  - Depends on: task-list approval.

- [x] Task 2: Remove obsolete artwork.
  - Acceptance: the five old arrow/slot SVGs have no active references and are removed.
  - Verify: inventory the icon bundle; confirm new English layer names and unchanged AppIcon integration.
  - Files: the five old SVGs in `Relente/Resources/AppIcon.icon/Assets/`.
  - Depends on: Task 1.

## Checkpoint A · Fidelity

- [ ] Review the real icon at 16, 32, 64 and 128 px and Dock size; preserve the drop and open counter.
- [ ] Review available Default, Dark, Clear and Tinted appearances on light/dark backgrounds.
      Record unavailable modes as pending. Present material design deviations to the owner.

- [ ] Task 3: Verify the compiled app's icon consumers.
  - Acceptance: Finder, Dock, app switching and Permissions display the new icon; the hero's
    halo, badge and accessible status remain correct without new image-loading code.
  - Verify: build with separate DerivedData; inspect safe sample UI with classic/current controls,
    light/dark appearance, Reduce Motion and VoiceOver. Inspect safely reachable system dialogs.
    Do not authorize an erase or install/uninstall the helper. Inspect legacy fallback outputs;
    record actual runtime OS versions tested, keeping unavailable macOS 14–15 checks outstanding.
  - Files: verification evidence in `specs/009-app-icon/spec.md`; no Swift edits expected.
  - Depends on: Tasks 1–2 and Checkpoint A.

- [x] Task 4: Refresh repository presentation.
  - Acceptance: 512 × 512 README PNG exported from the final Composer asset; product/build docs
    describe the identity, appearance configuration and repeatable export procedure.
  - Verify: inspect PNG dimensions/render; check README path and alt text; inventory active images
    for remaining old artwork while preserving historical specifications.
  - Files: `.github/assets/icon.png`, `BUILDING.md`, `docs/product.md`, `README.md` only if needed.
  - Depends on: Task 3.

## Checkpoint B · Consistency

- [ ] Bundle icon, Permissions hero and README show the same final design.
- [ ] Unavailable manual/OS checks remain explicitly outstanding.

- [x] Task 5: Run quality gates and review the diff.
  - Acceptance: Debug unit tests, universal Release build, strict swift-format lint and architecture
    check pass without warnings; only this feature's resources and documentation changed.
  - Verify: run AGENTS.md's commands as reproduced in `plan.md`; inspect the Release executable
    with `lipo -archs` for arm64 and x86_64; run `git diff --check`. No artwork-mirroring tests.
  - Files: evidence in `specs/009-app-icon/spec.md`.
  - Depends on: Tasks 3–4.

- [ ] Task 6: Reconcile with the completed helper work before integration.
  - Acceptance: after 008 reaches main, 009 preserves the final helper and shared documentation
    changes, with a reviewable icon-only diff against main.
  - Verify: refresh Git state, reconcile overlapping docs/index and rerun quality gates and affected
    visual checks on the combined tree. Do not edit, stash, reset or commit the other chat's work.
    Explicit owner authorization is required before any commit, push, PR or merge.
  - Files: `BUILDING.md`, `docs/product.md`, `README.md`, `specs/README.md`,
    `specs/009-app-icon/spec.md` if reconciliation needs them.
  - Depends on: Task 5 and spec 008 integrated into main.

## Checkpoint C · Final review

- [ ] Present final render, evidence and any remaining manual verification to the owner.
- [ ] Satisfy all spec acceptance criteria before claiming completion.
- [ ] Mark spec/index Done only in the authorized final commit of this feature's PR, before merge.

Evidence and the exact remaining manual checks are recorded in `spec.md` under Implementation evidence.
