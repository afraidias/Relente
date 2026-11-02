# 011 · Installer acquisition

**Status:** Approved · **Roadmap step:** 9 · **Branch:** `feature/011-installer-acquisition`

**Closure:** The owner has ended the `softwareupdate` acquisition approach and requested its
replacement by [spec 012](../012-direct-installer-download/spec.md). This spec is retained as
the record of the work and decisions made; it is not marked Done because cancellation was not
verified and the feature has not completed its own pull request. Its existing implementation and
unfinished checks must be assessed and carried forward under spec 012 before release.

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
- Begin loading Apple's catalog in the background when the Installer screen opens, in parallel
  with local installer and drive discovery. Keep local installer selection usable offline. When the
  Download state opens, show the latest catalog already loaded in this app session immediately; if
  the first request is still running, keep loading in the background. A failed prefetch is shown
  only if the user opens Download, with a retry action. Revalidate the selected version/build and
  destination before starting a download as specified below.
- List full installers currently offered by Apple's official mechanism for this Mac, limited to
  Big Sur and later. Show each available version clearly, newest first, with the catalog-reported
  download size when Apple provides it. Keep the release name on one line and version plus size on
  the second line; never add a third metadata line. Compatibility means
  availability for **this Mac**, not a promise that the resulting USB will boot another Mac.
- If Apple lists distinct builds for the same version, distinguish them by build and start a
  download only when the selected build can be requested unambiguously. If it cannot, leave that
  version unavailable rather than silently downloading another build.
- Identify an already available local installer of the same version and offer to use it instead of
  downloading it again. Offer reuse only for one complete, usable and unambiguous match. Match the
  exact version and, when both sources expose a build, the exact build. A local installer remains
  usable even if Apple no longer lists its version. If multiple local installers match, return to
  Installer so the user can choose; do not select one silently.
- Before starting a download, check again for a matching local installer and for an existing item
  at the destination Apple will use in `/Applications`. Never download over an existing installer.
  If the destination is occupied by an incomplete or invalid installer app, identify it in the
  Download state as unusable and offer the user the option to move that exact app to the Trash.
  Explain that it may be a partial or damaged installer and that Relente cannot determine which
  process created it. Require explicit confirmation naming the item before moving it. Re-scan the
  destination after the move; allow a fresh download only when it is clear. Never replace an item
  silently. Classify an app as incomplete only when its required installer files are missing or
  empty. If it is unreadable or ambiguous for any other reason, keep the download blocked and direct
  the user to resolve it in Finder.
  Different versions remain available when their destination is clear.
- The existing installer selection remains the source for the size shown on USB Drive and the
  capacity check. Do not advance to USB Drive until a complete, usable installer is selected.

### Download

- Selecting an available version starts a download only after an explicit user action. Show the
  version and progress in the Download state; show a percentage only when the underlying operation
  reports one, otherwise show an indeterminate indicator. Never invent progress or completion.
- While downloading, prevent starting a duplicate download. Before stopping, ask for confirmation
  that cancellation may require downloading the installer again; keep downloading is the default and
  Escape dismisses the confirmation. After confirmation, stay on the Download state. Only the active item's Cancel
  control cancels a download; activating its artwork opens the download details. Disable Back while a download is
  active. Disable the history controls during a download and keep an active older-version sheet open.
  Use the same native cancellation confirmation from the main grid, older-version sheet, and download
  details sheet, with identical wording and destructive action styling.
  When the user attempts to quit Relente normally during a download, show a native alert and keep
  the app open so the user can wait for the download to finish. The `softwareupdate` process
  exiting alone is not enough to establish that work in a system service has stopped. Do
  not expose a partial installer as selectable, and do not report cancellation until the operation
  has stopped. A force quit or crash can bypass this cleanup; any partial result remains unavailable
  after relaunch.
- On successful completion, verify that the resulting installer can be detected and used by the
  existing flow, add it to the local list, and select it. The user can then continue to USB Drive.
  Do not start creating media or installing macOS on the host.
- Keep the completed installer in `/Applications` across app launches and after creating a USB.
  Discover and reuse it on subsequent visits. Do not automatically delete a completed installer.
- When an incomplete or invalid installer app occupies Apple's destination, show it in the
  Download state as an unavailable item with a recovery action. The user may choose one or more
  identified invalid app bundles and confirm moving them to the Trash. This is a reversible move,
  never permanent deletion. Do not claim that Relente created the item. Do not offer cleanup while
  a Relente download is active. Before confirmation, tell the user not to proceed if macOS is
  currently preparing that installer. Revalidate that the exact app bundle is still structurally
  incomplete and unchanged immediately before moving it. Revalidate the destination before allowing
  a retry.
- Cleanup applies only to individually identified installer app bundles in `/Applications`.
  Never remove files from `/Library/Updates`, a content cache, or any other shared/system-managed
  location; those artifacts cannot be safely attributed to one full-installer fetch. Because
  `NSWorkspace.recycle` from the unprivileged app fails with `Permission denied` for Apple's
  root-owned apps, use one narrowly scoped typed helper request after explicit confirmation. The
  helper derives the requesting UID from the authenticated XPC connection, revalidates the exact
  installer bundle and moves it into that user's Trash. Preserve and surface any helper error.
- Keep incomplete-installer recovery compact in the Download screen: show a spaced warning summary
  without an item count and with a text-only review button, then open a native sheet to review the
  exact app bundles. In the sheet, show each app's Finder icon,
  name, version and size with a per-app Trash action. Keep the explicit confirmation and safety
  message with the selected item; do not put a long Trash button beside every item in the main grid.
  Keep the informational note at the bottom of the sheet with the system accent-blue info icon;
  size the sheet to its rows so the note does not float above a large empty area.
  Show the warning only after Apple's installer catalog has loaded successfully.
- If catalog loading fails, explain the failure in Download and offer a retry. If a download fails,
  keep its in-context recovery action and deliver a macOS notification so the failure is surfaced
  even when Relente is not frontmost. Overlay a retry symbol on the failed installer's artwork;
  activating that item retries the same version. Do not add a separate retry button below the grid.
  A failed or cancelled download is not reported as complete. Until the system-owned transaction
  can be verified as stopped, cancellation feedback says the request was made and macOS may
  continue downloading; it does not claim the whole download was cancelled.
- Selecting a version to download immediately opens a dismissible native detail sheet for that
  installer. Show its macOS artwork, name, version and catalog size, current progress and recent
  activity. The download belongs to Assistant state, not the sheet: dismissing the sheet does not
  stop the operation, and activating the active item reopens its details. Keep an older-version
  picker beneath the details sheet and restore it when details are dismissed.
- Retain the most recent 100 output lines from the active `softwareupdate` download in memory. Show
  them with timestamps in the detail sheet, updating as lines arrive. Clear the retained output when
  another download starts; never persist it to disk or imply that command output always explains
  the cause of a failure.

### Interface and accessibility

- The Download state follows the Installer picker's adaptive layout: show up to four release-family
  options in one row at regular item size; from five options, use the compact five-column grid and
  scroll only when needed. Count only the visible latest-version options, with no add-item slot.
  Use the same item sizes, column spacing, vertical spacing, scroll insets and edge fade as Installer.
  Show the newest available version in each macOS release family by default;
  older versions are opened in a focused native sheet from a visible per-family link, so they
  remain reachable without crowding the initial grid. The sheet reuses the same artwork and
  metadata layout, including download size, in a compact grid, without nested history controls. Directional-key navigation follows
  the visible grid. Use a compact, version-led artwork treatment when no exact local installer app
  exists instead of repeating the generic macOS application icon; use the real Finder icon for one
  complete exact local match. Do not invent version artwork from catalog metadata. Older-version
  choices use the same version artwork and metadata layout as the main grid. A version with one
  matching local installer offers **Use** instead of starting a download. Choosing **Use** selects
  that local installer and keeps Download visible. **Continue** then advances directly to USB Drive
  through the assistant's normal animated forward transition. When the selected local installer is
  in Download, its artwork participates in the shared transition and travels into the USB Drive
  screen, as it does from Installer. While Download is open, **Continue** is enabled only when the
  selected catalog version maps to the same complete local installer currently selected for the
  flow; a highlighted version that isn't downloaded cannot inherit a previous local selection.
  Keep the version and catalog size at the same type size and weight. Use a restrained chevron control
  beside the version, and reserve its space when a family has no older versions so every option keeps
  the same metadata-row height and alignment.
- Keep the grid and item heights stable while downloading. Reuse the flow's `ProgressRing` around
  the active installer's artwork with enough inset to separate the ring from the icon. When Apple
  reports a percentage, show it in the ring with a cancel control beside that version; emphasize a
  large number and a smaller gray percent sign, sizing them to use the available center area while
  staying inside the ring and clear of its track. Animate numeric changes with the shared rolling
  figure treatment, respecting Reduce Motion. When no
  percentage is available, center the indeterminate indicator over the artwork inside the ring;
  keep the cancel control beside the version. While cancellation is pending, disable Cancel and
  keep the waiting indicator centered inside the ring. Do not show a separate status panel or duplicate
  download copy. Confirm cancellation through macOS notifications. Give
  accessible feedback for observed preparation, download, and verification stages. The view works in
  light and dark appearances, with VoiceOver and Reduce Motion.
- Make each version's artwork and metadata one action sized to its visible content: **Download**
  starts acquisition and a unique exact local match is **Use**. Do not make empty grid space
  clickable or add a separate Download button. Keep the release name close to its smaller version
  label; omit build metadata. Use no download badge on idle artwork. The per-family history control
  uses a chevron in a capsule beside the version with a family-specific VoiceOver label. When an
  older catalog version has one exact complete local match, mark that control with the shared success
  badge and expose that an older version is available to VoiceOver; keep this distinct from the
  latest version's own local state. Keep the artwork area empty while an exact local app's Finder
  icon loads, then display the real icon without briefly showing version artwork. Place the native secondary Back
  text control immediately left of Continue in the assistant footer; place percentage inside the
  ring and the shared circular Stop cancel control beside the version in the active item and in
  the details sheet. Both sheets place the same rounded X
  button at the top right, using the app's secondary style and an explicit VoiceOver label.
- Keep vertical scrolling only when content exceeds the available space, show the scroll indicator,
  and apply the same top and bottom scroll-edge fade and content inset used by the Installer picker.
  The older-version sheet remains scrollable when needed. Its header shows the family name in bold
  with “Older versions” below in gray, both aligned to the left; each version/size row is centered
  without reserving space for controls that are absent.
- Show the pointing-hand cursor over enabled installer choices, the history link, and Cancel.
- Use the shared success `StatusBadge` for a local installer match; scale its Finder icon so it
  appears as large as the version artwork. Keep artwork close to its release name. Keep the
  older-version sheet open when a version starts downloading so progress and
  cancellation remain visible there. Keep selected local artwork visible in the older-version
  sheet; when continuing from Download, let the main Download item provide the shared transition
  into USB Drive. Selecting an already-local installer may return to Installer.
- The download detail sheet aligns its content to the top instead of vertically centering it in
  the available height. It presents the selected installer's artwork and progress on the left,
  with its name, version, size, status, and the shared circular Stop cancel control on the right.
  Center the artwork and
  details as a group, leave breathing room below the top close control before the progress artwork,
  leave generous vertical space between the progress hero and Activity divider, reducing that gap
  when a warning is shown and expand the sheet vertically so Activity retains a scrollable area.
  Activity fills the remaining sheet height and its output scrolls without clipping. Animate progress,
  installer artwork, completion badge, and warning changes with a restrained ease-in-out transition;
  crossfade the old and new artwork explicitly over 0.55 seconds, using a crossfade when Reduce Motion
  is enabled. Place the shared rounded X
  button at the top right. Make the full Activity
  label toggle its contents. Label
  cancellation with the same circular Stop control used on the active grid item, so it cannot be
  mistaken for Close. Show timestamped command output in a collapsible Activity section, expanded
  initially. The whole Activity header toggles the section; use a restrained fade instead of moving
  the log during collapse. Keep only the latest 100 command output lines in memory, clear them when a new attempt
  starts, and show them below installer details. Closing the sheet leaves the operation running;
  selecting the active item's artwork reopens it. For a download started from the older-version
  sheet, show details above it so dismissing details returns to that list. Do not add a separate
  activity button or sheet. Show download failures and blocked destinations once in a distinct,
  compact, leading-aligned warning callout with an icon and explanatory text. Download failures
  and blocked destinations are only shown in the details sheet, not repeated below the grid after
  the sheet closes. A failed download shows a centered retry symbol over its
  artwork and retries that version when activated. Catalog errors retain their list-refresh action.
  Omit the generic Download heading and status text that repeats the spinner or percentage. The
  close and Cancel controls have explicit accessible labels; cancellation still requires
  confirmation.
  On successful completion, replace the progress ring with an enlarged shared success badge using
  a scale-and-fade transition; use a crossfade when Reduce Motion is enabled.
- All new user-facing text is English with Spanish (Spain) translations in the String Catalog.
  The wording for errors, progress, and actions is reviewed with the design.

## Changes to earlier features

- **Spec 001 (Installer screen):** make “Download from Apple…” functional and introduce its
  Download state, completing the step 9 open item.
- **Spec 006 (Assistant navigation):** add navigation to and from Download within Installer;
  preserve the installer-before-drive order and existing accessibility and motion behavior. Show
  a pointing-hand cursor on enabled app controls throughout the existing flow.
- **Spec 007 (Real detection):** include completed retained downloads in the existing selection
  flow, expose build metadata when available for matching, and detect a matching local version
  before downloading; preserve manual local choice and the size check.
- **Spec 008 (System helper):** add one typed request to move a specifically confirmed,
  revalidated incomplete macOS installer app from `/Applications` to the connected user's Trash.
  The helper accepts no arbitrary paths or filesystem operations; completed installers and shared
  update data remain out of scope.
- **Spec 010 (Live installer creation):** feed the resulting installer into the existing creation
  flow, preserving its checks, authorization and helper security boundaries.

## Acceptance criteria

- [ ] Both Installer states open Download; local selection works without network access.
- [ ] The Apple catalog loads in the background while Installer is available; Download displays a
  previously loaded catalog immediately. A catalog failure does not block local installer
  selection, and starting a download still revalidates the catalog and destination.
- [ ] The list is obtained through Apple's official mechanism, reflects the installers it offers
  for this Mac, and excludes versions older than Big Sur; it does not claim compatibility with
  other Macs.
- [ ] Distinct builds of the same version are identified clearly. Relente starts a download only
  when the selected version/build can be requested unambiguously.
- [ ] An existing complete matching local installer is offered for reuse and a second download is
  not started; only one complete, usable version/build match is offered. Multiple matches are
  never selected silently.
- [ ] The initial grid shows the latest available version per macOS release family and follows
  Installer's four-item row / five-column compact-grid breakpoint and item sizes; a visible
  per-family link opens older versions in a native sheet using the same version-led artwork and
  metadata layout. Without an exact local `.app`, items use a version-led artwork treatment instead
  of repeating the generic application icon; exact local matches use their Finder icon. Catalog
  metadata is not used to invent version artwork.
- [ ] Before starting, Relente rechecks for a matching local installer and for an occupied Apple
  destination in `/Applications`; it blocks the download if the existing item could be replaced.
- [ ] At download start, refresh Apple's catalog once and reuse that result for the final policy
  check. Refresh local installers and recheck the destination immediately before starting the
  download, including after the destination has been marked as in progress.
- [ ] Activating an installer option itself starts a download, or uses a unique local match; there
  is no separate Download button and empty grid space is not clickable. The release name sits close
  to its smaller version label, with no build text. The grid height remains stable while downloading.
  The active artwork transitions into the flow's `ProgressRing`, scaling down as the ring appears;
  When the download ends, the ring transitions back into the artwork. Reduce Motion uses a
  crossfade. Its version item shows reported percentage
  at the center of the ring, or a centered indeterminate indicator when Apple reports no percentage;
  cancellation remains beside the version. There is no separate download status panel. Cancellation in progress is visibly
  acknowledged inside that item. Feedback reflects observed stages or percentage. Cancellation,
  failure and success have distinct, accessible states.
- [ ] Content scrolls only when needed, shows its scroll indicator, and has top and bottom insets and
  fades consistently with the Installer picker. Scrolling is disabled during a download in both the
  main grid and the older-version sheet.
- [ ] Back is a native secondary text control immediately left of Continue in the assistant footer. Download
  is the installer artwork/metadata action itself, with an explicit accessible name and a hit area
  limited to its visible content; build identifiers are not shown. A local match uses the shared
  success badge and appears as large as the version artwork. The older-version control uses a chevron
  and a family-specific accessible label, and the centered sheet
  closes with the shared rounded X button and centers its title. Older-version downloads remain visible in
  the sheet. Percentage
  and Cancel stay inside the active version item; percentage, indeterminate and cancellation-wait indicators
  are centered inside the ring, and Cancel is disabled while cancellation is pending.
  Enabled clickable items and controls use the pointing-hand cursor. The ring has visible space between
  its track and the artwork.
- [ ] Cancelling leaves the user on Download. While downloading, Back and the older-version
  chevrons are disabled; the active artwork opens download details. The detail sheet can be dismissed
  without stopping the operation; the active item retains progress and Cancel, and reopens details.
  An older-version picker remains available underneath its download detail sheet. The download
  sheet omits redundant status copy, uses the shared rounded X close button, and keeps cancellation compact.
- [ ] Prefetch the catalog at app startup while the permissions screen is visible. After a cancellation
  request and after a download failure, deliver a macOS notification when permission is
  granted. Separate release names
  and version labels visibly.
- [ ] A chevron in its own compact capsule opens a centered native sheet. The sheet uses one column
  for a single version and two columns for two or more versions; the single-version sheet is sized
  to fit its localized title and content without excessive empty space.
- [ ] During a download, the Cancel control replaces the history chevron beside the active version;
  older versions without a history control also show Cancel beside the version. Cancel remains
  disabled until cancellation finishes.
- [ ] Download selection uses the shared Installer selection plate and blue name capsule. The
  artwork uses the same regular icon and plate dimensions and spacing as Installer. The chevron
  uses a neutral capsule so the history control remains recognizable.
- [ ] Enabled app controls show the pointing-hand cursor on hover, including controls from earlier
  flow screens; disabled controls do not. Native system controls keep their platform behavior.
- [ ] Installer options show Apple's reported download size when available beside the version, in
  both the main grid and older-version sheet, so the user can compare download sizes before
  choosing. Keep the release name and version/size to at most two text lines below the artwork.
  Missing or unparseable size metadata is omitted without hiding an otherwise valid installer.
- [ ] An incomplete or failed download cannot be selected or mistaken for a completed installer.
- [ ] An incomplete or invalid installer app blocking Apple's destination is identified in
  Download without claiming it came from Relente. The user can select the exact app bundle, review
  its name in a confirmation, and move it to the Trash. Completed installers and shared/system
  caches are never cleanup targets; an active Relente download, or an app that is unreadable or
  ambiguous for reasons other than missing/empty required files, remains blocked for Finder
  resolution. A retry is offered only after the destination is revalidated as clear.
- [ ] Starting or reopening an active download shows a dismissible native detail sheet with the
  installer artwork, name, version, size, progress and latest 100 timestamped command output lines.
  Output remains in memory only and clears on the next download attempt. Closing the detail sheet
  leaves the download running; activating the active item reopens it. A failed option shows an
  accessible centered retry control over its artwork and retries that same version when activated,
  without a separate grid-level retry button.
- [ ] A normal quit request during a download shows a native alert explaining that the download
  is in progress and keeps Relente open so the user can wait for it to finish. The user may quit
  normally after the operation finishes. Cancel must stop the download operation before Relente
  reports cancellation; process exit alone is not treated as proof if system services may continue it. Any
  partial result remains unavailable after cancellation, force quit or relaunch.
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
  helper gains no networking, generic command execution, or weaker signature checks. Invoke the
  fixed `/usr/sbin/softwareupdate` executable with argument arrays, never through a shell.
- The helper continues to validate Apple's installer signature before creation. Acquisition does
  not treat a completed download as authorization to erase or as a substitute for that check.
- Never install macOS on the host as a consequence of downloading an installer. Never erase a
  destination as part of acquisition.
- Never overwrite or delete an existing completed installer to make room for a download.
- Moving an individually identified incomplete or invalid installer app to the Trash is allowed
  only after explicit user confirmation and a final helper-side check that the exact app bundle
  remains unchanged, Apple-identifiable and structurally incomplete. The helper accepts only a
  direct child of `/Applications` matching the installer naming convention, derives the requesting
  UID from its authenticated XPC connection, and chooses that user's Trash itself. It exposes no
  arbitrary move or delete operation. The confirmation tells the user not to proceed if macOS is
  preparing that installer. Never permanently delete it or clean shared/system-managed update
  caches.

## Edge cases

- No internet, an empty Apple list, an unavailable version, insufficient storage, or a failed
  download: explain the situation and preserve access to local installers.
- A local installer is moved, removed, incomplete, damaged, or changes during the flow: do not
  treat it as a usable match; preserve the existing disappearance and creation safety checks.
- Relente is force-quit or the Mac restarts during a download: a partial result must not be
  presented as complete. On relaunch, an incomplete installer app at Apple's destination is
  identified as unusable and can be moved to the Trash after explicit confirmation and final
  revalidation. The confirmation warns the user not to proceed if macOS is preparing the installer.
  If classification is uncertain, block another download and direct the user to Finder.
- Interrupting `softwareupdate` may leave temporary data in a system-managed cache outside
  `/Applications`. Relente never deletes that cache or claims to have reclaimed its space; only a
  complete, verified installer app can be selected.
- Multiple local installers describe the same version/build: do not choose one silently; return to
  Installer for a manual choice. If the version/build cannot be read, it is not a reuse match.
- Apple lists multiple builds of one version but its supported download command cannot select the
  requested build: keep that version unavailable rather than downloading an ambiguous build.
- An installer appears while a download is being prepared: check again before starting to avoid
  an unnecessary duplicate where the mechanism permits it.

## Decisions

1. **Apple determines availability for this Mac.** Apple documents
   [`softwareupdate --list-full-installers` and `--fetch-full-installer`](https://support.apple.com/en-us/102662)
   for compatible full installers, including progress and the Applications destination. Availability
   is not a guarantee for a different target Mac.
2. **Retain successful downloads.** This is part of the agreed acquisition capability and
   [issue #39](https://github.com/afraidias/Relente/issues/39); deletion is deferred.
3. **Reuse exact, unambiguous matches; never overwrite.** Match the exact version and, when both
   sources expose it, the exact build. Offer **Use** only for one complete, usable match; send
   multiple matches back to Installer for a manual choice. Block a download if its destination
   could overwrite an existing item. A different version remains downloadable when its destination
   is clear. Keep successful downloads in `/Applications`.
4. **Select before choosing a drive.** The actual installer size is needed for the existing drive
   capacity check; downloading does not authorize any erase.
5. **Keep the Download grid compact and stable.** Show only the latest version in each macOS
   release family initially; open older versions in a focused, card-grid sheet on demand. Keep
   progress and cancellation inside the active version item so a download does not change grid
   height. Keep the older-version sheet behind its download details while an older version downloads.
   Determinate progress is shown only when reported, following Apple's
   [progress-indicator guidance](https://developer.apple.com/design/human-interface-guidelines/progress-indicators).
6. **Use clear version-led artwork.** Apple's catalog has no version-specific artwork. Use a
   compact treatment led by the version when no exact local installer icon is available, and the
   real Finder icon for an exact complete local match.
7. **Match the Installer scroll treatment.** Reuse its top and bottom content inset and edge fade.
8. **Make the installer option the action.** The artwork and metadata are the Download/Use
   control. During acquisition the artwork uses the flow's `ProgressRing`; place percentage inside
   the ring and Cancel beside the active version, with centered indeterminate and cancellation-wait indicators.
   Open a dismissible detail sheet when a download starts, with installer information and recent
   command activity; closing it leaves the operation running and the active item can reopen it.
   Keep an older-version picker behind the details sheet. Put labeled Back beside Continue and
   matching rounded X close buttons in both sheets.
9. **Prefetch catalog data without trusting it for download authorization.** Load Apple's catalog
   in the background while Installer is open and reuse the in-memory result to make Download
   appear immediately. Keep the existing final version/build/destination checks before acquisition.
10. **Use a hand cursor for enabled app controls.** At the owner's request, show the pointing hand
    over clickable controls throughout the flow. This deliberately differs from Apple's default
    arrow for ordinary controls so click targets are easier to discover. System dialogs retain
    their native pointers. See Apple's [pointer guidance](https://developer.apple.com/design/human-interface-guidelines/pointing-devices).
11. **Keep download details in a dismissible native sheet.** The sheet is scoped to the selected
    installer and its ongoing acquisition. Closing it does not cancel the operation; its progress
    and reopen action remain on the Download grid, and an older-version picker is restored
    underneath. Use the circular `ProgressRing` for observed determinate progress and its
    indeterminate state otherwise; do not switch indicator shapes or use a Gauge for task progress.
    Center the ring and installer details together horizontally, with the ring on the left and
    metadata on the right; size the metadata stack to its visible content. Put recent command
    activity directly below the installer details. Roll the percentage digits with the shared
    `rollingFigure` treatment, respecting Reduce Motion. On
    completion, replace it with an enlarged success badge using a Reduce Motion-aware transition.
    This follows Apple's guidance
    for [sheets](https://developer.apple.com/design/human-interface-guidelines/sheets),
    [progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators),
    [action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets), and
    [gauges](https://developer.apple.com/design/human-interface-guidelines/gauges).
12. **Move invalid installer apps with a constrained helper operation.** These apps are owned by
    `root:wheel` in `/Applications`; `NSWorkspace.recycle` from Relente's unprivileged process
    returned `Permission denied` (NSCocoaErrorDomain 513) while renaming into the user's Trash.
    Keep the existing explicit confirmation, then ask the helper to revalidate and move only the
    exact incomplete Apple installer app into the Trash of the authenticated XPC caller. Do not
    add a general filesystem operation or allow permanent deletion. Apple's installer bundles
    contain expected framework symlinks, so both sides use the same snapshot algorithm; reject
    symlinks in the app's path, Info.plist, and required installer files, but allow bundle-internal
    links when snapshotting.

## Open items

- **Roadmap step 9, separate idea:** a user-controlled way to delete retained installers and
  reclaim space remains in [issue #39](https://github.com/afraidias/Relente/issues/39); this
  feature never deletes completed downloads automatically.
- **Roadmap step 8:** release validation, including Intel startup validation (issue #40), remains
  separate from this feature.
- **Roadmap step 9, final validation task:** establish whether normal quit can stop the full
  `/usr/sbin/softwareupdate` download transaction, not only its CLI, before Relente exits. Only
  macOS 27.0.1 is available for this check; other supported versions remain unverified. Foundation's
  [`Process.terminate()`](https://developer.apple.com/documentation/foundation/process/terminate%28%29)
  sends SIGTERM to the subprocess and its subtasks but can fail if a process ignores the signal.
  Apple's documented `softwareupdate` workflow and this macOS version's manual describe listing,
  fetching and progress, but provide no documented cancellation operation or `--cancel-download`
  option. Apple Support says `--fetch-full-installer` downloads the installer to `/Applications`,
  but does not document cancellation cleanup. A 2020 community answer points to `/Library/Updates`
  based on the then-current manual; it does not verify that directory as a safe deletion target on
  current macOS (see the
  [Ask Different report](https://apple.stackexchange.com/q/402077)). A local trial on macOS 27.0.1
  reached 5% with `Process.interrupt()` and 7% with `Process.terminate()`; both ended the CLI.
  `softwareupdated` reported an existing download transaction during each request. After the latest
  signal, no further service network activity appeared in the short observation window and no
  installer app appeared in `/Applications`, consistent with the transfer stopping; status and
  cache access still could not prove the service transaction ended or all temporary data was
  removed. A later log check showed a separate macOS 27.2 system-update transaction in
  `softwareupdated`, so daemon-wide activity cannot identify this full-installer transaction. On
  2026-10-29, the catalog listed macOS 27.2 (26B123, about 17 GiB), but a controlled
  `--fetch-full-installer` attempt remained at “Scanning for 27.2 installer”. At that time the logs
  showed a `DownloadAndPrepareUpdate` transaction for the same 27.2 build at about 3.0/15.3 GB;
  available evidence could not distinguish it from any request associated with the attempted fetch.
  The foreground CLI was interrupted, `softwareupdated` remained active, and no installer app
  appeared in `/Applications`. Do not retry the live transaction test while that system update is
  active; no cache was deleted.
  On the 2026-10-30 validation run, the owner-started 27.2 fetch reached 88%, then Relente reported
  failure. Retry was blocked by an existing `/Applications/Install macOS 27 Golden Gate.app`
  occupying Apple's destination; it measured 23 MB and was dated 2026-10-23. It was left untouched.
  A subsequent Big Sur 11.7.10 attempt reached preparation and was cancelled from Relente; the UI
  returned to idle, but service termination and partial-data cleanup were not verified. A direct
  `softwareupdate --list-full-installers` request then produced no output for over a minute and was
  interrupted. Do not inspect or delete partial data until the service is confirmed stopped. Final
  validation must determine whether cancelled full-installer data can be identified unambiguously
  and whether the service has stopped.
  Remove only artifacts proven to belong to that stopped fetch; never clear a shared Software Update
  cache such as `/Library/Updates` wholesale. If ownership or service termination cannot be proven,
  leave the data untouched and make sure it cannot be selected as a complete installer. Force quit
  and crashes cannot wait for cleanup; partial results must fail closed on relaunch.
  A later, separate Big Sur failure was traceable in `/var/log/install.log` to product `047-32248`:
  `softwareupdated` logged the transaction stopping and removing its foreground transaction, and
  `/Library/Updates/047-32248` was absent on inspection. `/Applications/Install macOS Big Sur.app`
  remained at about 20 MB with no `Contents/SharedSupport/SharedSupport.dmg`; it is not a complete
  installer and the app scanner does not accept it as one. This shows that structural validation
  can identify this unusable app bundle, but does not prove who created it or establish a general
  supported transaction-status API. `softwareupdate --dump-state` writes internal daemon state to
  logs, but is undocumented as a stable per-fetch status interface. Do not use log parsing or the
  mere absence of a package cache as general proof that a cancelled transaction stopped. Cleanup
  must be limited to a specifically identified app bundle, with a fresh structural check and the
  user's explicit confirmation. The confirmation warns against moving an item while macOS is
  preparing it; shared caches remain out of scope.

## Open questions

- **Unapproved investigation proposal — global Software Update service restart:** Could a narrowly
  scoped helper request, preceded by a distinct administrator authorization, stop and restart
  Apple's `softwareupdated` service and reliably end a Relente-initiated installer download?
  The request would have no caller-provided executable, command arguments, process identifier, or
  file path; the helper would verify the signed XPC caller and a dedicated right, and independently
  prevent conflicting helper operations. A successful service restart alone would not count as a
  cancelled download: the investigation must establish whether macOS resumes the transaction,
  what happens to partial data, and how a user is informed when the result is uncertain. This is a
  service-wide action that can interrupt unrelated update work; no cache deletion, service disabling,
  generic process control, or weakening of existing authorization and signature checks is proposed.
  The helper's current allowed operations in `AGENTS.md` and `SECURITY.md` do not include this
  action. The automatic approval review previously rejected the global service restart, and the
  later direct retry could not authenticate noninteractively. Do not implement or execute this
  proposal indirectly to bypass that rejection; obtain the required project and execution approval
  before any privileged trial. If the operation is permitted, test a controlled download on the
  available macOS version, recording the product, service PID, transfer state before and after,
  automatic restarts, and failure behavior; other supported macOS versions remain unverified.

  A reviewable prototype would require a separate Authorization Services right and one fixed,
  typed XPC request. The existing erase right is not sufficient: the app requests the new right
  through the system dialog and the helper verifies it independently without interaction. The
  existing mutually authenticated connection and shared operation gate must also apply to this
  request. Neither the requested action nor its parameters may be selected by the caller.
  Authorization refusal, an unavailable service, a failed restart and a restart whose effect on
  the download is unknown must remain distinct outcomes. In particular, restarting the service
  is not evidence that the installer download was cancelled.

  For a permitted real-device trial, capture the installer product identifier and service PID,
  begin a single download from the Xcode-launched app, then record the privileged request's result,
  the new service state and subsequent product-specific events over time. Check for a resumed
  transfer or retry and report an inconclusive result if termination cannot be established. Avoid
  the trial when another update is known to be active; absence of other update work cannot be
  guaranteed by this check. The trial must not remove shared update caches or partial files. This
  describes an experiment, not an approved helper capability or a promise of cancellation.

  Further investigation: Apple's macOS 14.4 release notes state that `launchctl kickstart -k`
  is disallowed for critical system processes. Mac administrator Graham Pugh specifically reports
  that restarting `softwareupdated` this way no longer works from 14.4. Neither source establishes
  that restarting the daemon cancels a full-installer transaction. Apple also documents that the
  MDM available-updates command excludes full-replacement InstallAssistant products on macOS 14
  and later, so it cannot be assumed to provide a transaction-specific alternative. Sources:
  [Apple's release notes](https://developer.apple.com/documentation/macos-release-notes/macos-14_4-release-notes),
  [administrator investigation](https://grahamrpugh.com/2022/09/29/software-update-check.html),
  and [Apple's MDM command](https://github.com/apple/device-management/blob/release/mdm/commands/system.update.available.yaml).
