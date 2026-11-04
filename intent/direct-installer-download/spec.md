# Direct installer download — design

Revision: 11 · State: Accepted
Related issue: N/A — no dedicated issue verified during conversion; roadmap step 9.
Approval: Afraidias, 2026-11-03, revision 8 — "vale, aplica lo ultimo del diseño que hemos visto y continua con lo que nos quede".
Previous approval: Afraidias, 2026-11-03, revision 7 — "vale me gusta, vamos con ello" after iterating the interactive prototype.
Previous approval: Afraidias, 2026-11-03, revision 6 — "apruebo" to the explicit complete revision 6 design approval question.
Previous approval: Afraidias, 2026-11-03, revision 5 — "okey" to explicit complete-design approval, including the extractor trust limitation.

Intent: [intent.md](intent.md) — revision 1 accepted by the owner on 2026-11-02.

Converted from the [existing draft](https://github.com/afraidias/Relente/blob/92a1608cd0f20476b79dab44794b5f718e02292e/specs/012-direct-installer-download/spec.md)
on 2026-11-02. This migration preserves proposed requirements, not evidence of implementation.

## Revision 11 — allow normal quit from an idle recovery state (Accepted)

Approved by Afraidias on 2026-11-04: an instance with no active acquisition must be allowed to
quit even when it has detected pending recovery work. Quitting leaves that work untouched and does
not clear the recovery block; a later launch still requires recovery before another download.
The existing wait/cancel behavior remains for an instance with an active acquisition.

## Revision 9 — proposed acquisition error and recovery presentation

State: Accepted. Approved by Afraidias on 2026-11-03 — "Aprobar propuesta".

Owner refinement, 2026-11-03: after reviewing the recovery prototype, show a visible centered
recovery explanation and Finder action even when system notifications are unavailable. Explain
that previous download files require review before another download, and that the user can return
to choose a local installer. This supersedes the no-inline-error rule for the recovery state.
Subsequent owner correction: make the header specific to recovery instead of asking the user to
choose from an unavailable list. Use a native empty-state hierarchy and concise copy that does not
claim which cleanup or process failed. Keep the Finder action and the existing Back navigation.
Apply the same visible, actionable empty-state principle when the catalog itself fails to load:
explain that the list is unavailable and offer a retry, without asserting a particular cause.

- Distinguish catalog/network failure from local recovery blocking. When Relente detects pending
  work or cannot prove cleanup, do not imply that Apple has no compatible installers or that the
  catalog request failed; the catalog request is blocked before it is made.
- Present acquisition errors through localized macOS system notifications, including catalog
  failures and recovery-required state. Do not repeat the error message inline.
- Keep the recovery action available in the Download screen: opening Relente's isolated installer
  storage in Finder lets the owner inspect the pending work. The action does not clear the block;
  only verified safe cleanup may do so. Keep local installer selection and USB workflow available
  where their existing safety rules permit.
- If notification authorization is denied, preserve actionable recovery access and expose the
  error to VoiceOver without claiming it was delivered as a system notification.

## Revision 8 — accepted connected stages and terminal presentation

The owner refined the details prototype on 2026-11-03: connect the four stage icons with a
subtle line; use green circular backgrounds for completed stages, blue for the current stage and
grey for pending stages, keeping each symbol legible. Animate transitions smoothly and use a
crossfade under Reduce Motion. Center the stage column against the ring itself, with the labeled
stop control below the ring. A completed installer shows its success artwork and all stages
complete. A cancelled transfer shows neutral stopped artwork and a retry control. Show "Installer
ready" and the cancellation/cleanup result through local system notifications only after their
verified terminal events; do not repeat these messages as inline status text. Wait for notification delivery before quitting after confirmed cancellation, when notification
permission allows it. Keep the terminal states available to VoiceOver even if notification
permission is unavailable. Owner clarification: use a consistent, restrained set of Apple SF Symbols for the stages
(network, down arrow, shield, shipping box), with one weight and monochrome rendering. No change to the
download trust, ownership or cleanup boundaries is authorized by this visual refinement.

Owner refinement, 2026-11-03: while a transfer is active, the catalog card retains its macOS
artwork and shows only a small activity indicator. It does not repeat numeric/ring progress or
offer cancellation outside the details sheet. Stabilize the downloaded/total text within the
details ring so updated byte counts do not move the layout.

## Revision 7 — accepted download-details layout

The owner approved the iterated "Etapas en el anillo" prototype on 2026-11-03. Keep the existing
progress ring as the main focus; show actual downloaded and total bytes in subdued text inside the
ring below the percentage, with spacing between them. Unknown totals remain truthful and the
ring stays indeterminate when progress is unknown. Place a labeled Cancel Download control with
a stop icon below the ring. Place four recognizable stage icons beside the installer name/version:
completed stages green, current stage accent, pending stages subdued. Provide accessible stage
names and statuses independent of color. Hide download speed for now. Preserve error, cancellation,
recovery, safe quit and Reduce Motion behavior. This refinement supersedes revision 6's speed
presentation but does not alter its underlying security or acquisition workflow. Existing accepted
plan revision 3 task 3 covers the view and accessibility changes; its existing verification gates apply.

## Revision 6 — proposed download presentation and version selection

Accepted by the owner on 2026-11-03. This section changes only the download presentation and which eligible
versions are offered; revision 5's security, eligibility, ownership, cancellation and helper
boundaries remain in force. Where the historical revision 5 text mentions an older-version sheet
or activity output, the following proposal replaces that behavior under this revision.

- Show the latest eligible version of **each macOS family**, ordered by OS version and build after
  the existing exact identity/compatibility and ambiguity checks. Keep older eligible candidates
  internally for verification, but do not expose an older-versions sheet or allow choosing an older
  release through this flow. If the latest release in a family cannot be verified as eligible on
  this Mac, do not present it as eligible; selection is limited to releases that pass those checks.
- Replace the command-oriented Activity area in download details with clear acquisition stages:
  Connecting, Downloading, Verifying and Preparing. Preserve actionable failure and recovery
  information. The existing creation log for the separate USB creation flow is outside this change.
- Mark Connecting complete only after an accepted HTTPS response from an allowed Apple origin;
  do not add a separate connectivity probe or imply all Apple services are available.
- During transfer show actual downloaded bytes, total bytes when known, percentage when a reliable
  total exists, and an observed transfer rate when sufficient samples exist. Do not fabricate a
  value before measurement; keep progress indeterminate where its denominator is unknown.
  Verification and preparation remain indeterminate unless their actual progress can be measured.
- Keep the existing cancellation, safe quit and recovery behavior. Make the revised information
  accessible to VoiceOver, compatible with Reduce Motion, and available in English and Spanish.

Owner clarification, 2026-11-03: "la última más reciente de cada familia". The owner subsequently approved revision 6 in full; the revised implementation plan requires separate acceptance.

## Conversion context

The host support target is Apple silicon and macOS 26.0 or later. This supersedes the source
draft's earlier host support assumptions without claiming project/CI alignment. Big Sur and
later is candidate installer scope, subject to verified availability and compatibility. The
previous acquisition work is not Done; reconcile its final UI, code and unfinished checks before
implementation. The converted draft has since been investigated against Apple sources and one Ventura package;
research evidence below does not establish production implementation or cross-release validation.

## Revision 5 — consolidated proposal for owner review

The normative proposal in this section refines the converted behavior below. Historical research
entries record what was known at each point; they do not override this proposal or imply approval.

1. **Catalog and compatibility:** use identified Apple HTTPS catalog/English Distribution metadata
   and intersect exact, unique OS version/build with a successful current-Mac full-installer list.
   Require one supported full-package layout and known package size. Missing/ambiguous identity,
   unknown layout or failed compatibility evidence disables that download with a useful reason.
   Do not promise all Big Sur-and-later versions. Local selection stays available offline.
2. **Origins:** initially allow exact swscan.apple.com for catalog and swdist.apple.com for
   Distribution/package metadata, swcdn.apple.com for full package content. Require HTTPS/default
   TLS, no URL credentials/nonstandard ports; bound metadata size, parsing and redirects. Use a
   default/ephemeral session so each redirect can be refused. Reject cross-role or unexpected
   origins and downgrade redirects. No wildcard domains or automatic CDN expansion. This is a
   deliberately bounded initial delivery policy; support other chains only after review.
3. **Transfer:** one owned acquisition at a time, real byte progress, separate verifying and
   preparing stages, stable operation identity and terminal callback/process acknowledgement.
   Requesting cancellation never means completion. After a cancellation wins the serialized
   transition, a late success cannot publish an installer. Quit and relaunch follow the same
   ownership/recovery rules; unknown termination/cleanup states remain visible and block reuse.
4. **Package trust:** take a stable complete snapshot, verify exact size and system package
   signature/trust, and bind the validated signer chain to reviewed Apple root/Software Update CA
   certificates. Use the observed root/intermediate SHA-256 identities documented in the signer
   investigation as the initial supported chain, not certificate display names or a leaf pin.
   Unknown rotation, ambiguous output or unavailable evaluation fails closed. No trust override,
   arbitrary embedded-certificate acceptance or silent resource-validation bypass.
5. **Preparation and retention:** preserve the signed package and prepare a derived candidate
   without executing scripts or installer/startosinstall. Only offer Ready after recognized
   structure, safe app links/types, support composition, independently Apple-signed executable
   and exact internal OS version/build match. Use the retained package for provenance; explain
   transfer versus preparation failures separately. Retained complete package/candidate deletion
   remains issue #39; no silent collision overwrite. No implementation claim follows from this.
6. **Privileged-use boundary:** reuse/refine the existing typed package-backed creation path,
   not a generic command or a new standalone preparation service. Following the existing USB
   authorization, helper creates and verifies its own private snapshot and derives its execution
   app from that snapshot; never trust a caller-writable candidate. Revalidate identity, executable,
   ownership/provenance and destination immediately before execution. Design/plan must account
   for the observed staged/original URL mismatch and support composition differences.
7. **Extractor trust assumption requiring acceptance:** rely on macOS's fixed system expansion
   tool handling an authenticated supported Apple package, inside private controlled staging.
   Reject unexpected layouts, enforce storage/time bounds and inspect result paths/types/links.
   A bounded filesystem limits data consumption, not the extractor's write authority. This design
   does not claim a root extractor is filesystem-sandboxed. Do not use deprecated sandbox-exec,
   custom archive decoders, private APIs or third-party dependencies as an improvised boundary.
   If the owner does not accept reliance on the trusted system extractor for signed Apple input,
   revisit preparation before coding; do not conceal that limitation as a passed safety check.
8. **Supported host/build separation:** Apple silicon/macOS 26+ remains the accepted host policy;
   changing targets, architectures or CI is a separate alignment task. Evidence from this macOS
   27.2 host is not validation on macOS 26 or another model. Helper/disk authorization rules stay.

### Required proof before integration

- A known-size real transfer cancels with terminal acknowledgement and no selectable partial,
  including after relaunch; test cancellation races, quit, network failures and stale callbacks.
- Cryptographic package verification rejects changed bytes, wrong chains, ambiguous output and
  unavailable trust. Internal OS identity must reject missing/conflicting metadata and match
  selection; do not use UI bundle/package versions as OS identity.
- Sample preparation and private-snapshot logic work without scripts, preserve required contents,
  reject path/link/collision surprises and terminate owned work before cleanup. Test the trust
  boundary with modified caller-writable candidates and replaced source packages. No real erase.
- Cancellation during verification/extraction and process termination failure are exercised,
  not inferred from successful expansion. Cleanup failures remain visible; no forced detach.
- Include Ventura and at least one current-generation supported package in research/validation
  before claiming broad package-family support; unknown layouts remain unavailable. Additional
  large downloads require a concrete size/storage proposal, not an unbounded catalog sweep.
- Preserve reviewed UI/local selection and verify applicable accessibility/localization/Xcode
  checks. Acceptance here authorizes later planning only; implementation requires accepted plan.

### Approval scope

Intent revision 1, current-Mac-only downloads, investigation of script-free extraction and the
retained-package/private-helper direction have been accepted individually. Full revision 5,
including the explicit system-extractor trust assumption, was accepted by the owner on
2026-11-03 ("okey" to the explicit revision-5 approval question). No implementation-plan,
merge or release approval is implied.

## Behavior

### Choose an installer

- Preserve the Download screen, family grouping, older-version sheet, local-installer reuse and
  selection behavior established in the previous acquisition work. Local selection continues to work offline.
- Offer Big Sur and later releases only when Relente can identify an Apple-hosted full installer
  and establish that the selected version and build are unambiguous. Do not represent the presence
  of a catalog entry as proof that it is compatible with this Mac. Use `softwareupdate` listing
  for compatibility only where an unambiguous match can be established; otherwise explain that
  compatibility cannot be confirmed and do not offer that download. The pilot offers downloads
  only when compatibility with the current Mac is confirmed; it does not offer unconfirmed
  downloads for other Macs. Offline local selection remains available.
- Show Apple's reported size when available. Refresh the chosen entry and recheck existing local
  installers and destination collisions before downloading. Reuse only a single complete,
  unambiguous matching local installer; never overwrite an existing item silently.

### Transfer and cancellation

- Download the selected Apple's package directly using a transfer owned by Relente and supported
  macOS networking APIs. Present real progress, an indeterminate state when the total is unknown,
  and the existing details and activity UI. Do not use `softwareupdate --fetch-full-installer` or
  modify system update services to perform the download.
- Preserve the existing cancellation confirmation and its safe default. On confirmation, request
  cancellation of every transfer belonging to this acquisition and keep the operation in a
  cancelling state until each has actually stopped. Only then report cancellation and allow a new
  download. Never report success or cancellation based solely on dismissing a view.
- Store partial files only in an app-controlled working area. After cancellation, remove or
  quarantine only artifacts proven to belong to this acquisition; never expose them as complete
  installers. Do not alter `/Library/Updates`, shared caches, other apps' files or unrelated work.
  If cleanup fails, tell the user and do not claim it succeeded.
- During an active operation, a normal quit presents a native choice to keep waiting or cancel the
  download. If cancellation is chosen, keep Relente running until transfer cancellation and safe
  cleanup have finished; then quit. Force quit, crash and shutdown can bypass this process. On
  next launch, detect and safely handle only Relente-owned incomplete work without assuming the
  previous operation completed.

### Verification and preparation

- Accept package metadata and redirects only from verified Apple-controlled HTTPS sources; reject
  unexpected origins, invalid certificates, missing or ambiguous identity and incomplete transfers.
  Validate the package's Apple signature before any package execution or extraction. Verify the
  resulting installer and `createinstallmedia` against the existing Apple-signature and structural
  checks before selecting or using them. A catalog checksum, if available, is an additional
  integrity check and is not a substitute for signature verification.
- Prepare the verified installer with a method proven to be safe on supported macOS versions.
  Package installation can run scripts or request privileges: until its behavior, authorization,
  destination, side effects, cancellation boundary and collision handling have been verified, do
  not automatically run it or imply that transfer cancellation can reverse preparation.
- Show transfer and preparation as distinct stages. If preparation cannot safely be cancelled,
  explain that state, prevent a false cancellation result, and allow normal quit only once the
  operation has finished or reached a verified safe stopping point.
- Select the completed installer only after validation succeeds. Retain it for reuse and proceed to
  USB selection through the existing flow; downloading never installs macOS on the host or starts
  USB creation. Give clear recovery for network, storage, validation and preparation failures.

## Changes to existing behavior

- **Previous acquisition approach:** Replace `softwareupdate --fetch-full-installer` acquisition and its uncertain
  cancellation with a Relente-owned direct transfer. Preserve its reviewed design, notifications,
  local selection, collision and incomplete-installer recovery requirements where applicable.
  Stop presenting raw `softwareupdate` output as activity for the new transfer; show actual
  acquisition and preparation events instead.
- **Existing local selection and USB creation:** Reuse existing installer detection, signature checks and USB creation
  requirements. This change does not relax helper security, disk validation or erase authorization.

## Acceptance criteria

- [ ] A real download from Apple's servers on the available Mac shows actual progress; cancelling
  at a known percentage stops the owned network task, waits for its terminal result and leaves no
  selectable partial installer. Verify after the UI returns to idle and again after relaunch.
- [ ] Normal quit during transfer offers waiting or cancellation and does not exit before a
  confirmed cancellation and safe cleanup. A force quit or crash never makes a partial selectable.
- [ ] An idle instance can quit while recovery work is pending; quitting preserves the pending work
  and does not make another download available.
- [ ] A completed real download is verified, prepared and detected as the requested version/build;
  it is usable by the existing USB creation flow without installing macOS on the host.
- [ ] Redirect, host, signature, integrity, version/build ambiguity, collision, interrupted transfer,
  insufficient storage, unavailable network and cleanup failures are rejected or surfaced without
  overwriting another item. Logic and security boundaries have automated tests.
- [ ] Existing local installer selection, previously reviewed Download UI, VoiceOver, Reduce Motion,
  light and dark appearance and native notifications remain functional.
- [ ] The real-device check records the macOS version, product and outcome; it does not claim
  verification on other macOS versions or models. Complete the required build, tests and lint.

## Boundaries

- Network access remains in the unprivileged app, never the helper. Do not add a generic helper
  command, a shell, private Software Update APIs, service termination or shared-cache cleanup.
- Keep the Apple signing requirements and existing administrator authorization for USB erasure.
  Any new privileged preparation capability needs an explicit security design and owner approval;
  it is not authorized by this draft.
- Do not add third-party app dependencies or alter signing, release settings or supported macOS
  versions without the owner's prior approval.

## Edge cases

- A catalog lists a build or package whose compatibility, Apple origin or identity cannot be
  established: show it as unavailable and explain why; do not silently choose another build.
- A cancellation races a completed transfer or preparation: resolve by the observed terminal
  state, never expose a partial as complete, and never destroy a verified existing installer.
- Relente is terminated during transfer or preparation: reconcile only its own working files on
  launch, without deleting an item being used or modified by another process.
- An old `softwareupdate` download from before this change may still exist in macOS: do not claim
  it is controlled or cleaned up by the new mechanism.

## Decisions

- Use Apple-hosted installer content with a Relente-owned transfer. This is distinct from Apple's
  documented `softwareupdate` workflow; Apple hosting alone does not establish that this whole
  acquisition workflow is officially supported. Apple's `URLSessionDownloadTask` supports task
  cancellation; the exact catalog, package verification and preparation workflow need validation.
- Real cancellation is required for the MVP. Do not substitute an optimistic notification or
  daemon-wide restart for a verified terminal transfer result.
- Carry forward the previous acquisition work’s user-facing work without marking its incomplete cancellation task Done.

## Open questions

- Which current Apple catalog and package metadata provide a reliable version/build-to-package
  mapping and compatibility for this Mac across supported versions?
- Which preparation method can produce the complete installer without unsafe package-script side
  effects, unexpected overwrites or expanding the helper beyond its approved security contract?
  What are its cancellation and authorization boundaries?
- Which Apple-controlled hosts and redirect rules are needed in practice, and how will they be
  validated without accepting arbitrary hosts or breaking legitimate Apple delivery?

## Open items

- Compatibility and live end-to-end verification on macOS versions or Mac models not available
  during development remain release validation for roadmap step 8; do not imply they passed.
- Deleting complete retained installers remains a separate roadmap step 9 item (issue #39).

## References

- [Apple: download and install macOS](https://support.apple.com/en-us/102662)
- [Apple: URLSessionDownloadTask](https://developer.apple.com/documentation/foundation/urlsessiondownloadtask)
- [Apple: create a bootable installer](https://support.apple.com/en-us/101578)
- [erase-install: installer acquisition modes](https://github.com/grahampugh/erase-install/wiki/3.-Downloading-a-macOS-Installer)
- [gibMacOS: Apple-hosted installer packages](https://github.com/corpnewt/gibMacOS)

## Approval record

Pending. All requirements and decisions above remain proposed until owner acceptance.

## Initial official-source investigation — 2026-11-02

Apple documents that [URLSessionTask.cancel()](https://developer.apple.com/documentation/foundation/urlsessiontask/cancel())
returns immediately; cancellation is acknowledged through the completion delegate callback, and
callbacks may still arrive beforehand. Therefore a cancelling UI state must not be treated as
terminal cancellation. This supports a Relente-owned transfer design but does not establish its
catalog or installer-preparation path.

Apple's [download completion callback](https://developer.apple.com/documentation/foundation/urlsessiondownloaddelegate/urlsession(_:downloadtask:didfinishdownloadingto:))
provides a temporary file whose lifetime must be handled before returning. Validation/publication
as a selectable installer remains a separate operation. This is API documentation evidence,
not an implemented or runtime-verified download workflow.

The Apple Support download/bootable-installer pages returned HTTP 429 during this investigation.
Their contents were not verified in this pass. Package source/identity, compatibility mapping,
Apple-controlled redirects and safe preparation remain open; no package execution or download
was performed.


## Design investigation — continuation, 2026-11-02

These findings extend the draft; they do not constitute design acceptance or runtime proof.

### Transfer origins and session choice

Apple's [redirect delegate contract](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:))
allows refusing a redirect in default and ephemeral sessions; background sessions automatically
follow redirects. Proposed: use a foreground default/ephemeral session and validate the initial
URL and every redirect before following it. Preserve normal system TLS validation. Require HTTPS,
reject credentials and unexpected ports, compare parsed exact hostnames against a reviewed list,
and bound redirects. Do not use substring matching or accept all Apple subdomains by default.
A bounded catalog/metadata sample is recorded below; the complete delivery chain and production
host policy remain unverified. A CDN IP or an Apple-looking filename is not origin evidence.

### Identity and compatibility are separate

Apple's [bootable installer guidance](https://support.apple.com/en-ie/101578) says the download
usually requires a compatible Mac and warns that installation can fail on an incompatible target.
Inference for Relente: distinguish the downloading/preparing Mac from the eventual USB target.
A softwareupdate listing can be evidence for the current Mac only; it cannot establish support
for an unspecified other Mac. On 2026-11-02 the owner chose the first option ("la primera"):
only offer downloads whose compatibility with the current Mac can be confirmed. Unconfirmed
cross-Mac downloads are outside this pilot. This accepts that design decision only, not the
complete design or implementation plan.

No documented public full-installer catalog API contract was found in this bounded official-source
search. This is not proof that none exists. Do not label an observed sucatalog schema as a stable
Apple API. Before accepting a catalog design, capture a bounded metadata sample from an identified
Apple HTTPS catalog and record product ID, full-installer discriminator, package URL/size,
version/build source, conflicting entries and freshness. Do not execute Distribution scripts to
read compatibility. Compare exact version/build against local softwareupdate listing where used;
missing/ambiguous build means unknown, not a match. Catalog package versions may differ from OS
versions; their equivalence has not been established here. Recheck identity from the complete
result, not its name or URL alone. A later bounded catalog observation is recorded below; no installer package was fetched.

### Preparation options and owner direction

| Option | Benefit | Unresolved risk / consequence |
| --- | --- | --- |
| Expand into Relente-owned staging without executing package scripts | Avoids deliberately running package installation scripts or adding a privileged preparation API | Must prove complete app layout, metadata, permissions and signatures survive; extraction and cleanup boundaries need tests |
| Install through Apple's Installer | Uses the package's intended installation mechanism | May authorize privileges, run scripts and write outside staging; cancellation, collisions and completion ownership need separate proof |
| Ask the user to prepare the downloaded package | Smaller automated surface | Does not fulfill the accepted integrated outcome without a scope review |

Owner selected **investigate isolated extraction** in this continuation chat on 2026-11-02.
This is authorization to investigate that option, not acceptance of this draft or permission to
execute a package. Installed `pkgutil(1)` documents `--expand-full` as expanding component Payload
contents into a new directory and `--check-signature` as checking signature validity/trust and
showing the certificate chain. Neither statement proves a particular InstallAssistant package
contains an immediately usable full installer. A trusted signature alone does not prove the
expected Apple identity; the exact package-signer policy still needs design and fixtures.
Apple's [packaging guidance](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
confirms packages can run custom installation code. Its archived
[signing guidance](https://developer.apple.com/library/archive/technotes/tn2206/)
distinguishes package signing from code signing. Do not apply app code-signing checks as if they
verified a flat package.

A future bounded preparation experiment must first verify the package and inspect its structure,
then expand only into a newly created owned directory, with no package-script execution. Check
path traversal/symlinks, resource limits, free space, destination collisions and preserved app
identity/signature/structure. Cancellation must wait for the owned extraction process to terminate
before cleanup. An interrupted result remains unpublished. Do not launch InstallAssistant or
startosinstall. No such experiment has run; a large package download and its storage budget still
need to be made concrete before running it.

### Read-only review of previous acquisition

Reviewed local branch `feature/011-installer-acquisition` at
`92a1608cd0f20476b79dab44794b5f718e02292e` relative to `origin/main` at `20d5d23`.
Reusable candidates include DownloadView, DownloadDetailsSheet, sample acquisition events,
local-selection/collision UI and associated localization/accessibility work. Review dependencies
before porting; do not merge the whole branch as completed functionality. Its live service uses
softwareupdate fetch and must be replaced. `AvailableInstaller.localMatch` and the service's
completion check permit missing build metadata; the new exact-identity design must reject an
unknown build as proof of an exact match. Existing incomplete-installer trash helper capability
is a separate security surface, not automatically required for app-owned staging cleanup.
No source files were copied or changed, and no old cancellation claim was revalidated.

### Evidence limitations

The English-US Support pages still returned HTTP 429. The Ireland bootable-installer page was
read successfully; the UK download page was available only as a search excerpt and then returned
429 on open. No runtime transfer, package verification/extraction, Xcode check or CI refresh ran.
Third-party search hits were not treated as authoritative evidence. Design and plan remain Draft.


### Bounded live metadata observation — 2026-11-02

Read the [Apple HTTPS catalog](https://swscan.apple.com/content/catalogs/others/index-26-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz)
with curl, a 40-second timeout and 16 MiB transfer limit, without following redirects. The web
reader could not access this URL; shell network access initially failed DNS in the sandbox and
succeeded with reviewed elevated network access. Observed 509,680 compressed bytes, 647 products,
and 21 products with a package URL ending in `/InstallAssistant.pkg`. This suffix was a research
filter, not an accepted full-installer eligibility rule. Catalog SHA-256:
`11ed0fee97a9674ead656c1f3ec8a9d2bce47518febf32e4293d4ece42cb5529`.

Sample product `142-50020` has `ExtendedMetaInfo.InstallAssistantPackageIdentifiers`, a package
URL on `swcdn.apple.com`, declared size 18,389,893,051 bytes, and a metadata/Distribution URL on
`swdist.apple.com`. Its [English Distribution XML](https://swdist.apple.com/content/downloads/38/31/142-50020-A_7SHECS0ACF/ncy3h2j7nwse4aoz0rjot59fp0z9s4yf3o/142-50020.English.dist)
was fetched with a 1 MiB limit and parsed as data only: `auxinfo` declares `VERSION=26.7.2` and
`BUILD=25G332`. XML size 10,057 bytes; SHA-256:
`8ecd78047654698a66713cc39604ae4c065ca8d111243756de45076782105b30`.
These are observed metadata claims, not a recommendation of this release, a signature check,
or proof of host/target compatibility. No Distribution code was executed. No redirects were
followed; package delivery redirects remain unknown. Observed hosts are candidates for review,
not an approved wildcard policy. Fetching a package or checking its signature remains pending.
Temporary research files reside under `/private/tmp/relente-catalog-research.*`; hashes and URLs
are persisted here because temporary files are not durable project evidence. The catalog is
mutable, so subsequent research must record a fresh sample rather than assume identical content.


### Current-Mac compatibility observation — 2026-11-02

The [bounded metadata observation](metadata-observation.md) records an exact unique version/build
join for all 21 entries returned by softwareupdate on this arm64 macOS 27.2 host. This supports
the proposed intersection of current-Mac listing and Apple package metadata, with fail-closed
handling for missing/ambiguous identities. It is runtime research evidence on one host, not an
accepted production parser or universal compatibility claim. The proposed package experiment
has a concrete candidate (18.39 GB) and provisional total working allowance (70 GB). No package
has been downloaded; package signer policy, archive structure and extraction containment still
need investigation before preparation can be called safe.


### Signed Ventura package observation — 2026-11-02

The owner-approved [Ventura inspection](ventura-package-observation.md) completed: exact-size
12.21 GB transfer, successful Apple Software signature evaluation outside the sandbox and
read-only structure/script inspection. This package uses the entire package as the app's
SharedSupport.dmg; Payload-only expansion or blindly copying the internal similarly named
entry is not equivalent. Package/app bundle version fields also differ from OS version.
Preparation remains unproven and requires a bounded composition/signature experiment before
design acceptance. No package scripts were executed and no installer was prepared or launched.


### Package-backed trust boundary proposal — 2026-11-03

See package-provenance-design.md for the proposed stable-package/private-helper snapshot boundary,
existing path/composition/cancellation integration questions and alternatives. A user-owned
prepared app with omitted resources must not receive the existing helper's trusted-package
exception. The recommendation remains script-free preparation, but its provenance guarantees
and effect on retained artifacts require detailed design and verification before implementation.
The owner accepted this direction on 2026-11-03 ("okey" to the explicit direction question);
complete feature design acceptance remains pending.


### Proposed operation states and terminal cancellation — 2026-11-03

The accepted direction retains the original package, prepares an unprivileged inspection
candidate, and independently prepares a private verified helper snapshot at authorized use.
These distinct stages must not share a single optimistic success/cancel flag. Proposed states:

| Stage | Completion proof | Cancellation / interruption handling |
| --- | --- | --- |
| Refresh/resolve | Exact unique current-Mac version/build and package identity | Cancel owned metadata requests; await terminal callbacks; no selectable artifact |
| Transfer | Terminal task success, acceptable HTTP response/origin and exact expected bytes | Request cancel for all owned tasks; await terminal callbacks, then cleanup; do not begin preparation after a late success if cancellation won the operation state |
| Package verification | Verified Apple package identity on stable complete bytes | Wait for owned verifier to finish/terminate before cleanup; never interpret interrupted verification as valid |
| Expand/inspect | Owned extractor exits successfully, reviewed layout/links, exact OS identity | Stop owned process tree and await terminal result; any uncertainty remains cancelling/recovery-required; no forced detach or success |
| Ready | Package retained, candidate inspected, metadata matches; publication is serialized against cancellation | No active acquisition process; local reuse remains subject to fresh validation |
| Private helper preparation | Independent verified snapshot, private provenance and exact identity, executable Apple verification | Separate authorized USB-operation lifecycle; acquisition cancellation must not claim to control it |

For transfer/preparation races, serialize state transitions per operation identity. A terminal
success callback after an accepted cancellation request must not publish a candidate. If Ready
was already committed before cancellation was accepted, report the actual complete result and
retain the installer rather than deleting it as partial work. No new operation starts until all
owned work is terminal or a truthful unresolved recovery state blocks it. Normal quit waits for
the same termination/cleanup protocol. Force quit does not establish terminal success; relaunch
revalidates only owned unpublished work and never promotes a stale 'completed' marker alone.

Do not promise prompt cancellation for the current blocking preparer; the implementation must
prove terminal process ownership first. Use cancellation-specific tests at each boundary, late
callbacks, verifier/extractor errors, failed cleanup/detach and relaunch. No cancellation runtime
claim is made by this state design or by the successful curl download.

### Completed-candidate identity evidence — 2026-11-03

The preparation experiment follow-up read the candidate support image in read-only mode. Its
74 software-update Assets all declare 13.7.8 / 22H730 with no missing/conflicting pairs, matching
the selected Ventura metadata. The exact metadata path/hash and successful mount cleanup are
recorded in preparation-experiment.md. Other package generations and helper revalidation remain
unverified; package/bundle UI versions are not substitutes for this OS identity.


### Preserved interface exception

Carry forward the owner's previously reviewed hand-pointer treatment for enabled app controls
from the 011 design (decision 10 in its source draft). This differs deliberately from the usual
macOS arrow to make app click targets discoverable; native system dialogs retain native pointers.
The current implementation port does not adopt the old system-cache/incomplete-installer trash
capability or optimistic cancellation language. Recovery here concerns only app-owned operations.

## Revision 10 — creation feedback without Activity

State: Accepted. Approved by Afraidias on 2026-11-04 — "apruebo". Prototype: [creation-feedback.html](../../../.codex/visualizations/2026/11/04/01a1a606-3237-7161-95f1-063805582ffe/creation-feedback.html).

Remove the Activity button, popover and separate creation-log window from the creation flow. Keep
the user informed on the creation screen itself with a clear current phase, its SF Symbol, and an
indeterminate animated progress indicator whenever the helper has not reported measurable
progress. Show measured copied bytes only during Copy and only when the value is available. Show
elapsed time as secondary information; omit guessed percentages, remaining time and “almost done”
claims when macOS has not reported them. Present the four named phases—Prepare and erase, Copy,
Make bootable and Verify—as a compact icon-and-label sequence, with the active phase highlighted.
Use localized English and Spanish text, complete unclipped labels, accessible phase/status
announcements and Reduce Motion behavior. Show actionable errors and terminal success directly in
the main creation flow. This change does not alter the helper operation, authorization, installer
source or creation boundaries.
