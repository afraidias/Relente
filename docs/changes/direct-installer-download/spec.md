# Direct installer download — design

Revision: 1 · State: Draft
Related issue: N/A — no dedicated issue verified during conversion; roadmap step 9.
Approval: Pending — conversion authorization is not acceptance of intent, design or plan.

Intent: [intent.md](intent.md) — Draft, acceptance pending.

Converted from the [existing draft](https://github.com/afraidias/Relente/blob/92a1608cd0f20476b79dab44794b5f718e02292e/specs/012-direct-installer-download/spec.md)
on 2026-11-02. This migration preserves proposed requirements, not evidence of implementation.

## Conversion context

The host support target is Apple silicon and macOS 26.0 or later. This supersedes the source
draft's earlier host support assumptions without claiming project/CI alignment. Big Sur and
later is candidate installer scope, subject to verified availability and compatibility. The
previous acquisition work is not Done; reconcile its final UI, code and unfinished checks before
implementation. This document preserves its successor draft and has not been technically
revalidated against Apple sources as part of conversion.

## Behavior

### Choose an installer

- Preserve the Download screen, family grouping, older-version sheet, local-installer reuse and
  selection behavior established in the previous acquisition work. Local selection continues to work offline.
- Offer Big Sur and later releases only when Relente can identify an Apple-hosted full installer
  and establish that the selected version and build are unambiguous. Do not represent the presence
  of a catalog entry as proof that it is compatible with this Mac. Use `softwareupdate` listing
  for compatibility only where an unambiguous match can be established; otherwise explain that
  compatibility cannot be confirmed and do not offer the download as compatible.
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
