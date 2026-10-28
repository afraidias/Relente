# 011 · Installer acquisition

**Status:** Draft · **Roadmap step:** 9 · **Branch:** `feature/011-installer-acquisition`

## Objective

Let someone choose an existing macOS installer or download an available installer from Apple,
then select a USB drive large enough for it. Show honest download progress and retain completed
downloads for reuse, avoiding another download when the same version is already available locally.

## Behavior

### Choose an installer

- Keep the existing local installer list, add control, file picker and drag-and-drop behavior.
  The user can choose a local installer without fetching Apple's list or connecting to the internet.
- “Download from Apple…” opens the Download state from either the populated or empty Installer
  screen. This remains part of the Installer step, before USB Drive.
- List full installers currently offered by Apple's official mechanism for this Mac, limited to
  Big Sur and later. Show each available version clearly, newest first. Compatibility means
  availability for **this Mac**, not a promise that the resulting USB will boot another Mac.
- Identify an already available local installer of the same version and offer to use it instead of
  downloading it again. A local installer remains usable even if Apple no longer lists its version.
  Match the exact version; display the build when available. Different version numbers remain available to download.
- The existing installer selection remains the source for the size shown on USB Drive and the
  capacity check. Do not advance to USB Drive until a complete, usable installer is selected.

### Download

- Selecting an available version starts a download only after an explicit user action. Show the
  version and progress in the Download state; show a percentage only when the underlying operation
  reports one, otherwise show an indeterminate indicator. Never invent progress or completion.
- While downloading, prevent starting a duplicate download. Provide a clear way to cancel and
  return to Installer. Do not expose a partial installer as selectable.
- On successful completion, verify that the resulting installer can be detected and used by the
  existing flow, add it to the local list, and select it. The user can then continue to USB Drive.
  Do not start creating media or installing macOS on the host.
- Keep the completed installer across app launches and after creating a USB. Discover and reuse it
  on subsequent visits. Do not automatically delete a completed installer.
- If the list or download fails, explain the failure and offer a retry or a return to the local
  installer choice. A failed or cancelled download is not reported as complete.

### Interface and accessibility

- The Download state follows the existing screen flow and design system, with keyboard navigation,
  a clear Back action, light and dark appearances, VoiceOver status and Reduce Motion support.
  The existing product description proposes a four-version grid and a progress ring; its final
  layout, including behavior with more versions, is subject to design review before approval.
- All new user-facing text is English with Spanish (Spain) translations in the String Catalog.
  The wording for errors, progress, and actions is reviewed with the design.

## Changes to earlier features

- **Spec 001 (Installer screen):** make “Download from Apple…” functional and introduce its
  Download state, completing the step 9 open item.
- **Spec 006 (Assistant navigation):** add navigation to and from Download within Installer;
  preserve the installer-before-drive order and existing accessibility and motion behavior.
- **Spec 007 (Real detection):** include completed retained downloads in the existing selection
  flow and detect a matching local version before downloading; preserve manual local choice and
  the size check.
- **Spec 010 (Live installer creation):** feed the resulting installer into the existing creation
  flow, preserving its checks, authorization and helper security boundaries.

## Acceptance criteria

- [ ] Both Installer states open Download; local selection works without network access.
- [ ] The list is obtained through Apple's official mechanism, reflects the installers it offers
  for this Mac, and excludes versions older than Big Sur; it does not claim compatibility with
  other Macs.
- [ ] An existing complete matching local installer is offered for reuse and a second download is
  not started; matching and ambiguous cases follow the approved rules.
- [ ] One explicit action starts a download; progress reflects real reported progress or is
  indeterminate. Cancellation, failure and success have distinct, accessible states.
- [ ] An incomplete or failed download cannot be selected or mistaken for a completed installer.
- [ ] A completed installer is detected, selected, retained after USB creation, and available
  again after restarting Relente. Its actual installer size is used before choosing a drive.
- [ ] Network, storage, unavailable version and cancellation errors allow recovery without losing
  an existing installer or claiming success.
- [ ] Tests cover listing and matching, duplicate prevention, state transitions, progress,
  cancellation, errors, and retained-installer discovery using injected sample services. Tests and
  previews do not download installers or touch real disks.
- [ ] Manual validation covers an Apple download, reuse after relaunch, and the full flow through
  USB selection and creation, without weakening existing helper safety checks.
- [ ] New views have previews, English and Spanish strings, keyboard and VoiceOver support, and
  work in light and dark mode, classic controls and Reduce Motion; the design is checked against
  Apple's macOS Human Interface Guidelines.

## Boundaries

- Acquisition runs in the unprivileged app through Apple's supported mechanism. The privileged
  helper gains no networking, generic command execution, or weaker signature checks.
- Never install macOS on the host as a consequence of downloading an installer. Never erase a
  destination as part of acquisition.
- Never overwrite or delete an existing completed installer to make room for a download.

## Edge cases

- No internet, an empty Apple list, an unavailable version, insufficient storage, or a failed
  download: explain the situation and preserve access to local installers.
- A local installer is moved, removed, incomplete, damaged, or changes during the flow: do not
  treat it as a usable match; preserve the existing disappearance and creation safety checks.
- Relente quits or the Mac restarts during a download: a partial result must not be presented as
  complete. The owner wants closing Relente to cancel the download; verify that Apple's mechanism can do so reliably before promising this behavior.
- Multiple local installers or multiple Apple entries describe the same macOS version: resolve
  identity without silently replacing a different build; see Open questions.
- An installer appears while a download is being prepared: check again before starting to avoid
  an unnecessary duplicate where the mechanism permits it.

## Decisions

1. **Apple determines availability for this Mac.** Apple documents
   [`softwareupdate --list-full-installers` and `--fetch-full-installer`](https://support.apple.com/en-us/102662)
   for compatible full installers, including progress and the Applications destination. Availability
   is not a guarantee for a different target Mac.
2. **Retain successful downloads.** This is part of the agreed acquisition capability and
   [issue #39](https://github.com/afraidias/Relente/issues/39); deletion is deferred.
3. **Reuse exact versions.** The owner chose an exact version match, displaying the build when
   available; a later version remains downloadable. Keep downloads in `/Applications`, warning
   and stopping if an existing installer could be overwritten.
4. **Select before choosing a drive.** The actual installer size is needed for the existing drive
   capacity check; downloading does not authorize any erase.

## Open questions

This draft is paused while permission and creation-flow research is undertaken; see
[`docs/research/permissions-investigation.md`](../../docs/research/permissions-investigation.md).


1. How should an incomplete installer or one with an unknown version or size be handled without
   risking a duplicate or silently choosing an unusable installer?
2. Apple's documented command places installers in `/Applications`. The owner chose to keep them
   there and warn and stop if a download could overwrite an existing installer. Confirm how to
   detect and prevent a collision with the supported mechanism on supported macOS versions.
3. Verify whether Apple's operation can reliably be cancelled when Relente closes, as the owner
   prefers, and determine what the UI can honestly promise if it cannot.
4. The owner chose the four-version grid with scrolling for additional versions. How should it
   present an existing installer and progress? Review the design and its HIG fit before approval.

## Open items

- **Roadmap step 9, separate idea:** a user-controlled way to delete retained installers and
  reclaim space remains in [issue #39](https://github.com/afraidias/Relente/issues/39); this
  feature never deletes completed downloads automatically.
- **Roadmap step 8:** release validation, including Intel startup validation (issue #40), remains
  separate from this feature.
