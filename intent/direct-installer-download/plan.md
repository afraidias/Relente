# Direct installer download — implementation plan

Revision: 3 · State: Accepted
Related issue: N/A — no dedicated issue verified; roadmap step 9.
Approval: Afraidias, 2026-11-03, revision 3 — "apruebo" to the explicit plan approval question.
Previous approval: Afraidias, 2026-11-03, revision 2 — "okey" to the explicit implementation-plan approval question.
Implementation state: In progress
PR: [#47](https://github.com/afraidias/Relente/pull/47) — draft, awaiting manual checks and owner review.

Intent: [intent.md](intent.md) · Accepted design: [spec.md](spec.md), revision 8.

## Revision 3 — presentation implementation plan (Accepted)

Owner accepted design revision 6 on 2026-11-03 ("apruebo"). Revision 2's remaining security,
verification and integration work remains open. The changes below supersede its tasks that preserve
older-version navigation or command-oriented download activity. No new implementation begins until
this revision 3 plan was accepted.

1. **Offer one release per family.** Select the newest verified, compatible candidate in each
   family using explicit version/build ordering; hide and remove the older-version sheet and its
   state, history controls and unreachable actions. Handle duplicate or ambiguous newest identities
   fail-closed, retain manual local installer selection, and ensure selected IDs/navigation refer
   to visible entries. Add focused tests for ordering, families, ambiguity and unavailable latest.
2. **Expose truthful transfer measurements.** Extend the existing owned transfer events with
   connecting/accepted-response state and measured downloaded/expected bytes. Confirm HTTPS status
   and allowed origin before indicating connection success, without a separate probe. Calculate
   observed speed from monotonic time and byte samples, omit it until meaningful, and keep unknown
   totals/progress indeterminate. Preserve redirect rejection, exact-size limits, single terminal
   callback, cancellation and cleanup behavior; test response errors, unknown totals, rate samples,
   stale callbacks and cancellation races through controlled transport.
3. **Replace download Activity with stages.** Bind Connecting, Downloading, Verifying and Preparing
   and measured progress to the existing details view; remove download-only output plumbing while
   retaining actionable failure/recovery and the independent USB creation log. Update sample data,
   previews, English/Spanish strings, VoiceOver labels and Reduce Motion behavior. Cover completion,
   cancellation, quit with details open, error and unknown-progress states using sample UI tests.
4. **Verify and review.** Run focused tests per slice, full unit and acquisition UI checks, universal
   Release and strict lint; document the pre-existing intermittent helper test and actual results.
   Review light/dark, VoiceOver and Reduce Motion where available, and record any unverified checks.
   Reuse the previously downloaded Ventura and 27.2 packages only if a real recheck is necessary;
   no additional large download or USB erase. Update product/security documentation and prepare a
   reviewable PR only after applicable evidence is complete. Owner approval remains required to merge.

Likely files: AvailableInstaller, AppleInstallerCatalogParser, InstallerDownload,
InstallerAcquisitionService, Live/SampleInstallerAcquisitionService, Assistant, DownloadView,
DownloadDetailsSheet, String Catalog and focused unit/UI tests. Order is 1 → 2 → 3 → 4; checks
follow each slice. The response callback/API must be verified against the existing deployment target
before choosing the precise hook; no implementation shortcut may weaken the accepted trust boundary.

## Scope and execution boundary

Implement Relente-owned direct acquisition, preserve local selection/useful previous UI, and
retain an authenticated Apple package with an inspected derived app. Before authorized USB use,
the helper independently prepares a private verified package snapshot. Never execute package
scripts, invoke installer/startosinstall, add generic helper commands or erase a real drive in
verification. Work only in this continuity worktree/branch; do not modify the separate checkout.
No third-party app dependency, target/signing/release/CI alignment or automatic publication.

The system extractor processing authenticated supported Apple input is the accepted trust
assumption; bounded storage is not a filesystem sandbox. Unknown metadata, certificate chains,
package layouts or terminal states fail closed. A failure requiring a different trust boundary
returns to design review, rather than adding a bypass. This plan uses the existing scheme and
automatic signing; compile-only unsigned Release checks are separate evidence.

## Ordered tasks

Each item is unchecked until code and stated proof exist. Proposed new filenames below are
implementation locations, not files already created. Keep each task focused; split if it expands
into independent concerns. Run focused Swift tests/lint per change, full project checks at the
integration checkpoint. Sequential execution; no subagents or new chats are authorized.

### 1. Preserve previous UI work and define reusable boundaries

Dependencies: none. Likely files: previous branch acquisition model/service contracts, sample
service and tests; inspect Assistant/View dependencies before any port (read-only first).

- [ ] Inventory the exact 011 UI dependencies and port only required contracts/sample behavior;
  omit softwareupdate fetch, unrelated changes and unverified cancellation claims.
- [ ] Preserve local offline selection and establish sample acquisition events for the new flow.
- Proof: focused existing local-selection/sample tests; review selected diff against the previous
  branch, no whole-branch integration. Separate UI porting is task 9.

### 2. Resolve an eligible Apple product

Dependencies: 1. Likely files: new AppleInstallerCatalog service/parser, AvailableInstaller model,
SoftwareUpdate listing parser and focused catalog tests (split transport/parser if needed).

- [ ] Parse bounded Apple catalog/Distribution data without executing scripts; require one known
  layout, package URL/size and exact OS version/build. Intersect with current-Mac listing only.
- [ ] Reject conflicts, absent identity, deferred/unavailable entries, missing sizes and unexpected
  origins. Recheck before acquisition; keep local-selection recovery available.
- Proof: sanitized observed metadata fixtures plus ambiguous/malformed/oversized/unknown-layout
  cases, stale selection and failed listing. Real metadata observation is supplementary evidence.

### 3. Verify the actual Apple package signer

Dependencies: 1; used by 5 and 7. Likely files: proposed shared AppleInstallerPackageVerifier,
existing provenance policy in CreateInstallMediaPipeline and focused verifier/policy tests.

- [ ] Require successful system package trust/signature evaluation on stable bytes and bind the
  validated chain to the accepted Apple root/intermediate identities; names alone do not suffice.
- [ ] Control language/output bounds; reject ambiguity, wrong chains, unsupported rotation,
  altered bytes, verification failure and unavailable trust. Do not modify trust settings.
- Proof: fixture-based result-policy tests and a system check of the existing signed sample plus
  a deliberately changed research copy. If the actual signer/output binding cannot be proved,
  stop for design review; do not invent a private API or accept arbitrary embedded certificates.

### 4. Own transfer and terminal cancellation

Dependencies: 1–2. Likely files: proposed direct-download service/delegate, operation state model,
owned working-directory policy and focused transfer/state tests.

- [ ] Use default/ephemeral URLSession, exact role-specific origins and reviewed redirects, real
  byte progress and an exact transfer limit. Keep operation identity across callbacks.
- [ ] Cancellation waits for every owned terminal callback, wins publication races correctly and
  blocks another operation until safe completion/recovery; no late callback selects a partial.
- Proof: controlled URLProtocol/test transport covering redirects, HTTP errors, unknown totals,
  truncated/oversized bodies, cancellation/completion races and stale callbacks. Do not replace
  the required real URLSession cancellation check with mocked evidence.

### 5. Prepare an unprivileged inspection candidate

Dependencies: 2–4. Likely files: InstallerPackagePreparer, new internal-OS-metadata reader,
staging resource policy and focused preparation/identity tests; split as necessary.

- [ ] Verify complete package snapshot before expansion, use fixed official tool and bounded
  private owned staging, no scripts; enforce known layout and safe file/link handling.
- [ ] Compose supported SharedSupport layout explicitly; reject missing/conflicting internal
  OS identity, mismatched build or executable signature failure. Retain package provenance.
- Proof: subprocess fixtures and safe small archives for path/type/collision/space failures;
  existing Ventura research for real expansion/composition/identity. Do not treat full-app resource
  omission as proof of integrity or grant the helper exception to user-owned output.

### 6. Make owned preparation cancellable and recoverable

Dependencies: 3–5. Likely files: shared owned-process runner/cancellation state, preparer,
working-artifact lifecycle and focused termination/recovery tests.

- [ ] Cancellation/timeout targets only owned work, observes terminal process-tree results and
  precedes cleanup/detach. Never force detach or report cancellation from a signal request alone.
- [ ] Publish Ready atomically with successful validation, reconcile owned unpublished work after
  relaunch, surface cleanup/termination uncertainty and preserve unrelated/verified files.
- Proof: cancellation during verification/expansion, late exit, refused termination, cleanup or
  detach failure and relaunch fixtures. Record limits of process-tree ownership on the toolchain.

### Checkpoint A — acquisition boundary

Tasks 1–6 pass focused tests/lint. Review catalog identity, signer-chain binding, terminal state
ownership and artifact publication against accepted design. Missing evidence or changed risk
returns to review; routine corrections stay within scope. No helper execution from a user app.

### 7. Derive a protected helper snapshot

Dependencies: 3, 5–6. Likely files: LiveCreateInstallMediaRunner, InstallerPackagePreparer,
PreparedInstallerPackage/provenance policy and focused existing helper-package tests (split
snapshot and runner integration changes into separate commits/tasks if scope grows).

- [ ] Copy and verify a private root-owned package snapshot independently; bind actual staged
  package path, app path and exact selected OS identity. Fix original/staged path routing.
- [ ] Validate trusted layout/permissions/symlinks, support composition, executable Apple signing
  and pre-launch provenance. Caller-writable candidates/manifests never authorize execution.
- Proof: injected file/process/verifier tests for replacement, path confusion, changed identity,
  ownership and signatures. Preserve existing destination/authorization/TOCTOU tests. No root
  extraction or disk erase is required to exercise these rejection/control paths.

### 8. Connect the existing authorized USB path

Dependencies: 7. Likely files: existing typed creation request/pipeline, InstallerSource metadata,
app request construction and focused request/pipeline tests.

- [ ] Carry package-backed source identity through the existing typed request with independent
  helper validation. Keep networking in app and admin/disk checks immediately before execution.
- [ ] Separate acquisition cancellation from authorized USB-operation lifecycle; no generic command,
  new standalone privileged service or accidental launch caused by acquisition completion.
- Proof: request/contract and injected runner tests for both package-backed and existing local
  sources, cancellation and fingerprint/authorization refusals. Do not alter the unrelated
  intermittent helper connection-loss test to make this work pass.

### 9. Restore the reviewed Download interface

Dependencies: 1, 4–6. Likely files: ported DownloadView/DownloadDetailsSheet and related components;
then separate Assistant integration/sample previews/String Catalog updates.

- [ ] Preserve family grouping, older releases, cancellation confirmation, activity details and
  local reuse; replace raw softwareupdate fetch output with actual acquisition/preparation events.
- [ ] Show truthful stage progress, errors, retained package/candidate status and Ready only after
  validation; prevent collision overwrites and accidental destructive/default actions.
- Proof: sample previews, focused UI tests and English/Spanish strings; check layout and keyboard
  behavior against native macOS guidance. Port dependencies deliberately, without resurrecting fetch.

### 10. Handle quit, relaunch and accessibility

Dependencies: 6, 8–9. Likely files: app lifecycle/delegate and Assistant cancellation integration,
UI test fixtures and accessibility/localization adjustments in focused substeps.

- [ ] Normal quit waits for confirmed cancellation/cleanup or offers continued waiting; forced exit
  leaves recoverable unpublished work, never a selectable partial. No control of old system fetches.
- [ ] Preserve notifications and local selection; verify VoiceOver, Reduce Motion, keyboard access,
  light/dark appearance and applicable sample-flow UI tests.
- Proof: automated state/relaunch tests plus recorded native UI/accessibility checks. Use existing
  scheme/signing; unavailable environments/checks are explicit limitations, never passes.

### Checkpoint B — real proof and integration readiness

Dependencies: all tasks. No unchecked criterion may be silently marked complete.

- [ ] Propose concrete current-generation installer size/storage before any additional large
  download. Validate one recent supported layout alongside Ventura; unsupported layouts stay
  unavailable. Real URLSession transfer cancellation at a known percentage, terminal confirmation,
  idle/relaunch artifact checks and quit behavior must be recorded, including failure recovery.
- [ ] Check signature/identity from actual retained and prepared artifacts and test private helper
  preparation via safe seams; no real device erasure. Record host/model/OS and package scope.
- [ ] Run Debug unit tests through existing Xcode project/Relente scheme with automatic signing,
  universal compile-only Release build and full strict swift-format lint as AGENTS.md specifies.
  Diagnose signing failures; do not use copied apps, alternate projects or signing overrides.
- [ ] Review affected security code and complete acceptance criteria; human owner review is required
  before merge. Do not claim independent agent review. Refresh actual CI/PR status before reporting
  integration readiness; unrelated flaky-test history remains a separate recorded limitation.
- [ ] Update docs/product.md, README/BUILDING if behavior requires, security docs if affected, and
  this artifact's actual results/limitations. No SDD revival or edits to original third-party skills.
- [ ] Keep changes reviewable on the current feature branch; respect conversation publication scope.
  Merge and release publication require separate explicit authorization.

## Risks and return-to-review conditions

Unknown package generations or certificate chains fail closed. If exact internal identity cannot
be established, a package cannot be offered Ready. If private snapshot ownership, authenticated
input, path safety, system extractor assumptions or terminal cancellation cannot be demonstrated,
stop that path and return to design; do not substitute privileged installer scripts or weaker
verification. No guarantee for another host/macOS follows from this sample. Existing target/CI
alignment and retained complete-installer deletion remain separate work.

## Approval and continuity

Owner accepted intent revision 1 and complete design revision 5 (2026-11-03, explicit "okey" to
the revision-5 approval question). This implementation plan revision 2 remains Draft, awaiting
owner acceptance. No source implementation has begun. Artifact location follows the accepted
intent/ convention. Evidence below is chronological research history, not completed build tasks.

## Execution evidence

2026-11-02: source draft converted into these three artifacts with owner authorization. No code,
external issues, original spec, project or CI configuration changed. No implementation tests or
live downloads performed. Intent, design and plan acceptance remain pending.

2026-11-02: started feature/direct-installer-download from integrated main at 20d5d23 in the
migration worktree, leaving the separate acquisition checkout unchanged. Owner accepted intent
revision 1 ("vale"); design and plan remain Draft/unaccepted. Initial official-source findings
are recorded in spec.md. Next: resolve metadata/compatibility and preparation options, assess
reuse from PR #44, then present design decisions. No source/project/CI changes or live transfer.


### Continuation checkpoint — 2026-11-02

Verified clean worktree at `/Users/afraidias/.codex/worktrees/ai-native-sdlc/Relente`, branch
`feature/direct-installer-download`, HEAD `74b406e` before these documentation edits.
Read AGENTS.md, development guide and all three change artifacts. Older memory of an unintegrated
migration is superseded by the verified origin/main ref at `20d5d23` and the supplied PR #45 context.
The other checkout was not modified. Reviewed previous acquisition source read-only and added
source-backed transfer/preparation findings and options in design revision 2. Owner chose to
investigate isolated extraction; cross-Mac download policy remains pending. No design or plan
acceptance, source/project/CI edits, commit, push, PR or merge occurred.

Next: resolve the cross-Mac policy, inspect a bounded Apple catalog/metadata sample to establish
exact identity and origins, and define a concrete download/storage budget for a signed-package
structure experiment. Do not execute package scripts or start implementation. Official-source
contracts support redirect control and package expansion but do not yet prove catalog stability,
Apple package signer policy, or usable full-installer reconstruction. Required documentation
verification: inspect diff and local Markdown links. App build/tests are inapplicable to these
prose-only edits. CI post-merge status was not refreshed in this continuation.


Follow-up in the same continuation: bounded live catalog and one Distribution XML were fetched
and parsed as data, with URLs, sizes, hashes and observed identity saved in spec.md. No installer
package was fetched. Next metadata work: inspect conflicts/full-installer discriminators and
compare a bounded sample with current-Mac compatibility evidence; the sample alone does not
settle the catalog design. Package experiment budget and cross-Mac policy remain unresolved.


### Owner decision — current-Mac compatibility, 2026-11-02

Owner selected "la primera": offer only downloads whose compatibility with the current Mac
can be confirmed. Recorded in design revision 3. Unconfirmed cross-Mac downloads are outside
the pilot; offline local selection remains available. This resolves the policy question from
the preceding checkpoint, not the technical evidence needed to establish compatibility.
Design and implementation plan remain Draft and unaccepted. Next: validate an unambiguous
version/build match between Apple catalog metadata and current-Mac compatibility evidence,
then define the isolated preparation experiment and its storage budget.


### Research checkpoint — current-Mac join, 2026-11-02

Read-only list query outside the sandbox exited 0 after the initial sandbox invocation stalled
and its owned CLI was stopped. All 21 version/build pairs match unique catalog products; sizes
agree within integer-KiB rounding. See metadata-observation.md for environment, table, limitations
and the proposed 18.39 GB package / 70 GB working allowance. No package download, extraction,
source edits, Xcode changes or implementation checks. Next: agree the concrete large-download
experiment, establish package signer policy, inspect archive structure, and resolve enforceable
extraction containment before running extraction. Design and plan remain Draft/unaccepted.


### Authorized package research — Ventura, 2026-11-02

Owner requested a smaller candidate and accepted Ventura 13.7.8 / 22H730 (product 093-22004),
12,205,110,942 bytes, instead of Tahoe. Authorization covers download, signature verification
and structure inspection without installation or executing package scripts. Download started
in unique directory `/private/tmp/relente-ventura-research.BCNVcZ`, partial filename
`InstallAssistant.pkg.partial`. curl uses HTTPS, normal TLS validation, no redirect following,
exact declared maximum filesize and an 1,800-second transfer timeout. Initial HTTP response is
200 with Content-Length matching the catalog and no redirect. Transfer remains in progress;
no success, authenticity or extraction claim yet. Do not publish/select this research artifact.
Next: observe terminal result, compare exact length, check package trust/Apple signer and inspect
archive structure. Scripts may be read as data only. No implementation or design acceptance.


### Completed Ventura inspection — 2026-11-02

Transfer exited 0 after 1,400 seconds with exact declared size. Apple package signature passed
outside the sandbox; the sandbox gave a misleading invalid result. Read PackageInfo and scripts
as data, extracted only small inspection entries, and identified package-as-SharedSupport
composition plus OS/package/bundle version differences. See ventura-package-observation.md for
hash, commands, results, failed tools and limitations. Package retained in the documented unique
temporary directory. No package script/install execution, image mount, /Applications write,
feature code or Xcode/CI changes. The authorized download/signature/structure goal is complete.
Next: design a storage-bounded expansion/composition research experiment and resolve Apple app
signature/OS-identity verification, then review the design. No plan/design acceptance inferred.


### Concrete preparation research proposal — 2026-11-02

Added preparation-experiment.md: a 32 GiB research image, ordinary-user official expansion,
explicit Ventura package-as-SharedSupport assembly, strict Apple code-signature and exact
OS-identity checks, and owned-process terminal cancellation/detach recovery. Consulted installed
hdiutil(1) for sparse capacity and mount options. Storage isolation is explicitly not filesystem
path confinement. No image was created/mounted and no expansion/assembly ran. The proposal is
Draft; product implementation remains unapproved. No additional download is needed for this
Ventura research. Next: review/execute the concrete research protocol within authorization,
then use actual findings to finish the feature design rather than treating this proposal as proof.


### Preparation research result — 2026-11-02

Executed the owner-acknowledged bounded experiment. Official expansion succeeded, app symlinks
stayed internal and createinstallmedia passed strict Apple-anchor signature verification. Both
untouched extracted and assembled apps failed strict full-app verification due to obsolete
custom omit rules. Stopped and normally detached the research image; package and sparsebundle
retained. Exact completed-app OS identity and cancellation remain unverified. See the experiment
execution record. No implementation or design acceptance. Next: investigate the signing-policy
compatibility question and the owner's requested comparison with Mist's source code.


### Owner-requested Mist comparison — 2026-11-02

Read Mist source at e2067cc8f4f398b458c9c88a3569042e28659419. Findings in mist-comparison.md:
owned URLSession download with chunk integrity checks, temporary-image package installation via
privileged helper (scripts execute), and no equivalent strict full-app verification in the
reviewed flow. Its cancellation UI dismisses without awaiting all terminal operations. No Mist
code was executed or adopted; Relente security and current research failure remain unchanged.


### Signature-policy diagnosis — 2026-11-03

Reviewed official strict-validation/error contracts, local codesign manual and current helper
flags. Reattached research image read-only. Both candidate and untouched apps fail ordinary
resource-verifying Apple-anchor validation even without --strict/--deep. Catch-all omission rules
exist in the original app envelope; removing strictness is not a fix. See
signature-policy-investigation.md for evidence and proposed provenance proof obligations. No
resource-skipping check was accepted or code changed. Next: specify a package-backed integrity
and immutability boundary for script-free preparation, or revisit the preparation option with
owner review. Product design and plan remain Draft; no implementation authorization inferred.


### Provenance design checkpoint — 2026-11-03

Added package-provenance-design.md and design revision 4. Read existing package preparer, helper
private-copy ownership/signature gate and pipeline provenance checks. Proposed retaining the
original package and independently preparing a private verified snapshot at privileged use;
user-writable preview output is not trusted as execution source. Recorded unresolved original/
staged URL routing, support-image composition, signer policy and in-command cancellation. No
helper execution, code change or completed-app validation. Next material review: accept or revise
the proposed retained-package/private-preparation boundary, then finish design evidence/tasks.
No design/implementation-plan approval has been inferred from routine research acknowledgments.


### Direction acceptance — 2026-11-03

Owner explicitly accepted the retained Apple package / unprivileged inspection / independent
private helper preparation direction, replying "okey" to the direction-acceptance question.
Updated package-provenance-design.md approval scope and spec.md. Complete feature requirements/
design and implementation plan remain Draft/unaccepted. Continue detailed research/design on
exact completed OS identity, package cryptographic identity, extraction containment, cancellation
and proof obligations. Do not start implementation or treat this as merge/release approval.


### Continued accepted-direction research — 2026-11-03

Verified actual candidate support metadata: 74 consistent OSVersion/Build entries, 13.7.8 /
22H730. Both read-only mounts were detached normally. Added proposed stage-specific completion/
cancellation semantics to spec.md, explicitly separating acquisition from later authorized
helper preparation. No runtime cancellation test or helper operation executed. Next unresolved
design work: cryptographic package signer policy, extractor confinement/resource limits in the
privileged path, bounded compatibility handling beyond this sample and final UX/recovery review.
Then present the complete design for acceptance before completing implementation planning.


### Signer and containment research — 2026-11-03

Public root and Software Update CA certificates linked by Apple PKI match the sample's validated
chain hashes. Added a proposed system-verification-plus-reviewed-chain policy, explicitly
distinguishing actual signer validation from untrusted embedded certificates and covering
rotation/output ambiguity. Confirmed sandbox-exec is deprecated; image storage limits do not
provide path confinement. Production isolation/trust assumptions require explicit design review.
No code, new dependencies, keychain changes, mounts or package execution. Next: consolidate these
security choices and UX/failure requirements into a reviewable complete design; it remains Draft.


### Consolidated design ready for review — 2026-11-03

Spec revision 5 now presents exact proposed catalog/origin eligibility, verified-chain policy,
retention/private snapshot boundary, terminal cancellation and proof requirements together. It
explicitly surfaces reliance on the fixed macOS extractor for authenticated supported Apple
packages; bounded staging is not claimed as filesystem sandboxing. This is the material owner
review point. No implementation work is authorized before the complete design and subsequent
implementation plan are accepted. Evidence remains sample-specific; current-generation package,
runtime cancellation, helper private snapshot and supported-host checks are future proof tasks,
not completed acceptance criteria. No additional download or source change was made.


### Artifact home alignment — 2026-11-03

Owner requested following the playbook's recommended intent/ location. Moved the full artifact
tree from docs/changes/ to intent/ without losing existing modified/untracked research files;
updated project instructions, contributor/build docs, PR template and relative links. Original
chronological migration records may still mention the former location as historical evidence.
No third-party skill, source code, Xcode/CI setting, other checkout, commit or remote changed.

The owner had also accepted complete design revision 5 on 2026-11-03, replying "okey" to the
explicit revision-5 approval question including the system-extractor trust assumption. Record
that approval in spec.md; implementation planning was interrupted by this artifact-location
review and remains incomplete/unaccepted. Next: finish the implementation plan in this file
using the accepted design. This path-only change does not alter the accepted product scope.


### Implementation plan drafted — 2026-11-03

Replaced the obsolete planning skeleton with revision 2's ordered task/checkpoint plan after
owner acceptance of design revision 5. Preserved chronological investigation evidence. No code,
commit, push, PR, other checkout, original skill or project/CI setting changed. Next: owner review
and acceptance of implementation plan revision 2; do not implement before that acceptance.


### Implementation authorization — 2026-11-03

Owner explicitly accepted implementation plan revision 2 ("okey" to the approval question),
then instructed "continua". Starting implementation in the continuity worktree only. No merge
or release publication authorized. Existing artifact-home/documentation changes are preserved.


### Implementation checkpoint — 2026-11-03

Added exact-build local matching, consistent all-asset identity parsing, bounded catalog/origin
parsing and compatibility intersection. Added a one-shot URLSession transfer with terminal
cancellation and collision protection. Focused tests passed after correcting an arithmetic
fixture/import issue. Added reviewed-chain fingerprint policy and an owned typed-tool process
group runner; its actual pkgutil check of the downloaded Ventura sample passed in the existing
scheme. Added private bounded extraction workspace, staged-path routing correction and complete
package SharedSupport composition; focused preparer/helper/workspace tests passed. No physical
device operation, new download, Xcode/CI/signing override, commit or push.

Tasks remain incomplete: UI/sample-contract port, live acquisition orchestration/persistence,
helper exact identity binding, runtime active-transfer/preparation cancellation, recent-package
validation, accessibility and complete project checks. Bounded preparation is undergoing an
opt-in real Ventura check through the existing scheme; do not count it as passed in advance.

### Acquisition and helper checkpoint — 2026-11-03

Implemented the selected acquisition UI/contracts, owned URLSession transfer, bounded catalog
intersection, authenticated script-free preparation, exact support OS identity, retained Ready
index and independent helper package snapshot. Protocol version is now 6 to carry the expected
version/build. Ready markers never replace content verification. Unfinished app-owned work blocks
new acquisition after relaunch; uncertain process/mount state is retained for recovery.

Actual Ventura checks passed: native bounded preparation (49.845 s), Apple package signature
policy, and active transfer cancellation after 1,064,960 of 12,205,110,942 bytes with terminal
callback observed and owned transfer directory empty. The two new sample-data UI tests now pass:
completion through installer selection to USB selection, and safe Return/default cancellation
confirmation followed by explicit terminal cancellation. Explicit default-action shortcuts were
needed for native macOS confirmation sheets. No USB operation occurred.

Full unit tests, real expansion cancellation, full lint and Release checks are still in progress.
A new recovery-store test initially used a noncanonical temporary path rejected by the existing
path-safety control; corrected the fixture to resolve system symlinks, without weakening the
control. Added regression coverage that recovery blocks both repeated create and write checks.
Remaining review includes helper recovery across daemon restart, real retained/relaunch behavior,
manual accessibility/appearance checks and current product/security documentation.

Owner explicitly authorized the additional recent-generation validation download in this chat.
Refreshed official catalog/distribution metadata confirms product 142-50055, macOS 27.2 / 26B123,
17,807,147,403 bytes. Research download is in progress under
/private/tmp/relente-recent-generation-142-50055; not yet verified or prepared. Its curl transport
is a research fixture, not evidence of full acquisition-service completion. No scripts, USB
operations, commit, push, merge, release, other checkout or project/CI settings were changed.

### Verification and recovery follow-up — 2026-11-03

Full unit run passed after resolving the pending-path guard: Foundation normalizes an existing
/private/tmp root to /tmp even in standardizedFileURL, while a nonexistent child keeps its
literal /private/tmp path. The guard now checks literal and resolved paths. The test remains
strict for nonexistent children; no assertion was removed. Root recovery discovery tests also
pass without following symlinks or deleting evidence.

The helper operation gate previously replied before its deferred release, permitting a follow-up
request to race that release. It now ends ownership before terminal reply. The disconnect/cancellation test assertions and suite scheduling remain unchanged. A temporary
serialization experiment was reverted to preserve the accepted plan boundary; concurrent tests
still share the daemon-wide gate, which remains a known potential test interference source.
Actual expansion cancellation passed in 26.715 s during the earlier full run. Full strict lint
passed. Full UI regression, added normal-quit test, further lifecycle tests and Release remain
in progress. Catalog working folders now live under the same pending store so a crash or lost
listing process is detected on relaunch. Root-owned six-character mkdtemp preparation directories
block helper write checks and creation after a daemon restart; uncertain work is not auto-deleted.

### Recent validation checkpoint — 2026-11-03

The owner-authorized macOS 27.2 research download completed: HTTP 200, 17,807,147,403 bytes,
product 142-50055, build 26B123, at /private/tmp/relente-recent-generation-142-50055/
InstallAssistant.pkg.partial. It has not yet been verified or prepared. A modified APFS clone of
Ventura was rejected by pkgutil with a checksum error. The live catalog and its cleanup passed;
the three acquisition UI tests passed, including quit from the main window. The larger UI run
had 29 passes and the quit test failure before its test was adjusted to close the details sheet.
Quitting while that sheet is open needs further investigation. The same unrelated helper test
also times out on main's CI run 41534341621; no assertion or suite scheduling was weakened.

Ventura preparation, Ready publication and reload proof is running in the existing scheme:
/private/tmp/relente-ventura-retention-proof.log. Next: inspect its result; run the same test
with TEST_RUNNER_RELENTE_PREPARATION_PACKAGE pointing to the recent package, and set
TEST_RUNNER_RELENTE_PREPARATION_VERSION=27.2 and TEST_RUNNER_RELENTE_PREPARATION_BUILD=26B123.
Then run Release, full lint, review current failures and accessibility, update this plan and
prepare an appropriate draft for review. No commit, push, PR, merge, release or USB erase yet.

### Two-generation preparation proof — 2026-11-03

The existing-scheme native preparation, code and exact identity checks, Ready publication and
revalidation after reload passed for Ventura 13.7.8 / 22H730 (87.610 s) and macOS 27.2 / 26B123
(129.146 s). Both bounded workspaces were removed after confirmed completion. The universal
Release build completed successfully. No package scripts or USB operations were executed.
Evidence: /private/tmp/relente-preparation-proof-22H730.json and
/private/tmp/relente-preparation-proof-26B123.json. Remaining: final lint result, review the
quit behavior while the details sheet is open, the pre-existing intermittent main CI failure,
accessibility/manual checks, and integration review. No commit, push or PR has been made.

### Quit-sheet investigation — 2026-11-03

With the details sheet open, Quit did not expose the expected confirmation in the UI test.
An attempted sheet-based NSAlert did not resolve the failure and was reverted, along with its
test change. The previously passing main-window quit test is preserved. The details-sheet quit
behavior remains unresolved and requires investigation; do not mark the quit criterion complete.
The final full lint passed before this reverted experiment. No commit, push or PR was made.

### Quit from download details — 2026-11-03

Instrumented the termination delegate and confirmed that AppKit's standard Quit menu action
never invoked it while the SwiftUI details sheet was open. Replacing the app's Quit command with
an explicit action made the confirmation visible. After the user chooses cancellation, the app
waits for acquisition termination and cleanup, asks SwiftUI to dismiss the download sheets,
waits for their dismissal, then requests normal termination. The termination delegate remains in
place for other system-initiated quit paths. The UI test now keeps details open and checks both
Return/Keep Waiting and Cancel Download and Quit. All three acquisition UI tests passed; universal
Release and full strict lint passed after the code change. Added the Spanish Quit label.


### Proposed presentation revision — 2026-11-03

Owner clarified the latest eligible release of each macOS family should be offered and requested
reconsideration of command-style Activity and consideration of observed connection, byte counts
and rate. Revision 6 of spec.md is Draft for review; its proposal replaces the older-version
sheet and command-oriented activity only after acceptance. Do not implement the changed behavior
before design and any needed plan changes are accepted. Existing implementation and evidence
remain intact; no new code, commit, push, PR or release was made for this proposal.

### Revision 6 design accepted — 2026-11-03

The owner explicitly approved the complete revision 6 design ("apruebo"). Revision 3 of this
plan is Draft for the owner's separate review. Existing work and its evidence are preserved; no
revision 6 behavior has been implemented.

### Revision 3 plan accepted — 2026-11-03

Owner explicitly approved revision 3 ("apruebo"). Implementation may proceed within its scope.

### Revision 3 implementation checkpoint — 2026-11-03

Implemented one unambiguous latest eligible version per family, removed older-version navigation,
and replaced download-only Activity with Connecting, Downloading, Verifying and Preparing stages.
After a 200 response from the allowed Apple origin, the transfer publishes measured byte counts and
monotonic sampled rate; unknown totals/rates remain unavailable. The independent USB creation log
is unchanged. Added Spanish strings and focused selection, rejected-response and rate tests.

Focused tests passed, as did the three acquisition UI tests (including cancellation and quit with
an open details sheet), universal Release build and full strict lint. Actual Apple transfer
cancellation was repeated after the change: requested at 1,081,344 bytes of 12,205,110,942;
the terminal callback was observed and the owned directory was empty. No large download or USB
erase was needed. The full unit run failed on the same 60-second HelperRequestHandler connection
loss timeout already observed on main CI run 41534341621; its test was not weakened. Manual
VoiceOver, Reduce Motion and light/dark checks remain unverified. Do not mark integration ready
until remaining checks and owner review are resolved. No commit, push, PR, merge or release.

### Download-details prototype accepted — 2026-11-03

Owner approved the iterated ring-focused prototype ("vale me gusta, vamos con ello"). Design
revision 7 records its layout and removes visible download speed for now. Implement this view
refinement under accepted plan revision 3 task 3; retain its verification and security gates.

### Approved ring layout implemented — 2026-11-03

Implemented the owner-approved ring layout: measured percentage and byte counts, labeled stop
button below the ring, and four stage icons beside the installer; completed stages are green,
current stage accent and remaining stages subdued. Stage labels/statuses and the ring's percentage
and bytes are exposed to accessibility. Download speed is not shown. Visual inspection of a
sample-data capture confirmed the layout; the three acquisition UI tests passed, including safe
cancellation and quit. Universal Release and strict lint passed. The full unit run still failed
on the pre-existing 60-second helper connection-loss timeout also seen on main CI. Manual actual
VoiceOver, Reduce Motion and dark appearance checks remain open. No commit, push, PR or USB erase.
The subsequent linked-icons and completed/cancelled screens shown in conversation are proposals,
not yet approved for implementation.


### Verification and UI refinement checkpoint — 2026-11-03

The owner accepted the linked-stage/ring terminal presentation and then selected Apple SF Symbols
network, arrow.down, shield and shippingbox. The latest card refinement keeps its macOS artwork
with a small activity indicator during a transfer; numeric progress and cancellation stay inside
details. The measured byte label has a fixed width to avoid layout jumps. Completion and confirmed
cancellation use localized system notifications, with quit awaiting notification submission after
terminal cleanup. The acquisition and helper trust boundaries did not change.

The helper timeout was traced to parallel tests of HelperRequestHandler sharing its production
process-wide operation gate. The suite now uses Swift Testing's serialized trait without changing
any assertions. The full Debug unit suite with project signing passed (442 cases), including the
formerly timed-out connection-loss test. Three acquisition UI tests passed before this checkpoint;
the focused cancel/details UI test passed again after the card refinement and once with a dark-mode
launch argument. That argument did not visibly switch the captured app appearance, so this is not
proof of a dark-mode review. The existing dark preview is available; actual dark appearance,
VoiceOver and Reduce Motion operation remain unverified. Universal Release compile-only build and
strict lint passed after the card change. No real USB erase, new large download, commit, push, PR
or merge occurred. Next: finish visual/accessibility review where possible, update the product
description and inspect the final diff, then prepare the reviewable branch/PR under the approved
publication scope. Owner review and approval are still required for merge.


### Remaining before integration

- Inspect actual dark appearance and Reduce Motion in the running app, and complete a human
  VoiceOver pass. UI automation has checked accessible labels and status values, but does not
  replace these manual checks.
- Record final signed build and CI results in the PR. The local Release check is compile-only
  and does not exercise the live privileged helper or a real USB device.
- Obtain owner review before merging. Xcode's "Update to recommended settings" suggestion is a
  separate project-settings decision and is not a compiler warning in this change.


### Draft PR checkpoint — 2026-11-03

Commit 0fda065 was pushed on feature/direct-installer-download, directly above the accepted
intent commit 74b406e. Draft PR #47 targets main. Local unit, focused UI, Release and lint
results are recorded above and in the PR; CI and manual appearance/accessibility review are
pending. No merge or release is authorized by opening the draft.


### PR checks and accessibility review — 2026-11-03

Draft PR #47 reports success for PR title, Lint and Build & test CI checks. The acquisition UI
tests expose a named, frequently updated progress ring; named stages with Completed, In progress
and Pending values; and accessible ready/cancelled terminal states. Code inspection confirms
Reduce Motion disables ring and rolling-number animation, substitutes opacity for artwork motion,
and shortens state transitions. Xcode Preview's Dark canvas failed with "Failed to launch app
Relente.app in reasonable time"; a prior app launch argument also left the captured interface
light. Therefore actual dark-appearance rendering, spoken VoiceOver navigation and observed
Reduce Motion behavior remain unverified. These need a human pass in a running app before merge.
