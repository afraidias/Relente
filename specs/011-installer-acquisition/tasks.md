# 011 · Installer acquisition — tasks

Plan: [plan.md](plan.md) · Spec: [spec.md](spec.md)

## Verification Commands

- Focused test (set `TEST_NAME` to a test type, e.g. `SoftwareUpdateOutputParserTests`):

  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme Relente -destination 'platform=macOS' \
  -only-testing:RelenteTests/TEST_NAME
  ```

- Run unit tests:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
  ```

- Run the UI flow:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -scheme Relente -destination 'platform=macOS' \
  -only-testing:RelenteUITests/AssistantFlowUITests
  ```

- Build universal Release:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build -scheme Relente -configuration Release \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
  ```

- Run strict lint:

  ```sh
  xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests
  ```

## Phase 1: Models and local matching

- [x] Task 1: Model Apple installer entries and parse command output
  - Acceptance: Catalog versions/builds and reported progress parse into typed `Sendable` values;
    missing, malformed, or ambiguous output fails closed.
  - Verify: Run `SoftwareUpdateOutputParserTests`; cover multiple builds, unknown fields, invalid
    output, determinate progress, and indeterminate progress.
  - Files: `Relente/Models/AvailableInstaller.swift`,
    `Relente/Services/SoftwareUpdateOutputParser.swift`,
    `RelenteTests/SoftwareUpdateOutputParserTests.swift`
  - Dependencies: None
  - Scope: Small

- [x] Task 2: Expose installer build metadata and exact reuse matching
  - Acceptance: Local installer build is exposed when readable; reuse requires one complete exact
    version/build match and never selects ambiguous candidates.
  - Verify: Run `InstallerMetadataTests` and `InstallerSourceTests` for readable and missing build
    metadata, exact matches, and multiple matches.
  - Files: `Relente/Models/InstallerSource.swift`, `Relente/Models/InstallerMetadata.swift`,
    `Relente/Services/InstallerReader.swift`, `RelenteTests/InstallerMetadataTests.swift`,
    `RelenteTests/InstallerSourceTests.swift`
  - Dependencies: Task 1
  - Scope: Medium

### Checkpoint: Matching foundation

- [x] Catalog parsing and local matching are deterministic and fail closed.
- [x] Focused tests pass; no real installer or disk is accessed.

## Phase 2: Acquisition service

- [x] Task 3: Define acquisition service and sample implementation
  - Acceptance: The protocol represents catalog load, download states, progress, cancellation, and
    failures; the sample service supports previews/tests without running commands or using network.
  - Verify: Run `InstallerAcquisitionServiceTests` against sample success, cancellation, and errors.
  - Files: `Relente/Services/InstallerAcquisitionService.swift`,
    `Relente/Services/SampleInstallerAcquisitionService.swift`,
    `Relente/Resources/Localizable.xcstrings`,
    `RelenteTests/InstallerAcquisitionServiceTests.swift`
  - Dependencies: Tasks 1–2
  - Scope: Small

- [x] Task 4: Run the Apple catalog command through an injectable process runner
  - Acceptance: The live service invokes fixed `/usr/sbin/softwareupdate` arguments without a
    shell and returns parsed versions or a recoverable error; tests use a fake runner.
  - Verify: Run `LiveInstallerAcquisitionServiceTests`; assert executable/arguments and exercise
    empty, valid, and malformed catalog responses through the fake runner.
  - Files: `Relente/Services/SoftwareUpdateRunning.swift`,
    `Relente/Services/ProcessSoftwareUpdateRunner.swift`,
    `Relente/Services/LiveInstallerAcquisitionService.swift`,
    `RelenteTests/LiveInstallerAcquisitionServiceTests.swift`
  - Dependencies: Task 3
  - Scope: Medium

- [x] Task 5: Prevent duplicates and protect installer destinations
  - Acceptance: Before a download can start, the live service refreshes Apple's catalog and the
    local installer watcher, then rechecks one exact local match and the Apple `/Applications`
    destination; it offers reuse or blocks a collision without replacing anything. Duplicate-start
    protection is verified with Task 6.
  - Verify: Run acquisition policy and service tests for a race-time matching installer, occupied
    destination, ambiguous catalog builds, and a clear different-version destination.
  - Files: `Relente/Services/InstallerAcquisitionPolicy.swift`,
    `Relente/Services/LiveInstallerAcquisitionService.swift`,
    `RelenteTests/InstallerAcquisitionPolicyTests.swift`,
    `RelenteTests/LiveInstallerAcquisitionServiceTests.swift`
  - Dependencies: Tasks 2–4
  - Scope: Medium

- [x] Task 6: Stream progress and represent download outcomes
  - Acceptance: The service reports only observed progress, prevents concurrent downloads, exposes
    distinct success/failure/cancel states, and makes incomplete results unavailable.
  - Verify: Run acquisition service tests using fake process output for progress, no percentage,
    failure, cancellation, and termination; no live download in automated tests.
  - Files: `Relente/Services/LiveInstallerAcquisitionService.swift`,
    `Relente/Services/SoftwareUpdateRunning.swift`, `Relente/Services/ProcessSoftwareUpdateRunner.swift`,
    `Relente/Services/InstallerService.swift`, `Relente/Services/LiveInstallerService.swift`,
    `RelenteTests/LiveInstallerAcquisitionServiceTests.swift`
  - Dependencies: Tasks 3–5
  - Scope: Medium

### Checkpoint: Service behavior

- [x] Sample-backed tests never launch `softwareupdate`.
- [x] Live service uses argument arrays, never overwrites, and returns only typed states.
- [x] Strict swift-format lint passes.
- [x] The full unit-test run is clean. The helper plist is bundled with the test target so the
  contract test does not read outside the test bundle.

## Phase 3: Installer flow and interface

- [x] Task 7: Integrate Download as an Installer substate and prefetch its catalog
  - Acceptance: Both Installer states open Download; Back returns to Installer; Use selects the
    unique local match and keeps Download visible; Continue advances to USB Drive only when the
    selected Download version maps to the same complete local installer selected for the flow,
    animating that installer's shared artwork into Drive. A non-local selected version cannot
    continue using a previously selected installer.
    Prefetch the Apple list in the background while Installer is visible and reuse the successful
    in-memory result when Download opens.
  - Verify: Run assistant/navigation unit tests and sample-backed Installer UI tests; confirm a
    prefetched list appears without another request and failed prefetch can be retried.
  - Files: `Relente/App/Assistant.swift`, `Relente/App/RelenteApp.swift`,
    `Relente/Views/AssistantView.swift`, `Relente/Views/InstallerView.swift`,
    `Relente/Views/DownloadView.swift`, `Relente/Resources/Localizable.xcstrings`,
    `RelenteTests/AssistantTests.swift`
  - Dependencies: Tasks 3–6
  - Scope: Medium
  - [x] Implemented: Download is an Installer substate; catalog loading starts with app startup,
    and a successful in-memory result is reused when Download opens. Assistant tests cover prefetch,
    navigation, retry and using a completed sample installer.

- [ ] Task 8: Refine the Download grid and progress presentation
  - Acceptance: The latest-version options use Installer's adaptive layout: up to four regular
    items in one row, then five compact columns with scrolling only when needed. The older-version
    sheet keeps its agreed one/two-column sizing. Catalog-reported download sizes share the version
    line in both grids, keeping each option to at most two metadata lines below its artwork. It preserves all
    distinct builds; makes visible artwork and metadata the Download/Use hit area; places a labeled
    native Back control beside Continue; removes build labels and idle download badges; uses version-led
    artwork or the exact local app icon; reuses the flow's ProgressRing around active artwork and
    puts reported percentage and the same circular Stop control used in the details sheet in that
    version item; gives feedback while
    cancellation is pending; centers indeterminate and cancel-wait indicators over the artwork
    inside the progress ring with visible inset between ring and icon; shows scroll indicators;
    uses a pointing-hand cursor over clickable controls; matches Installer's scroll-edge fade/insets;
    supports keyboard, VoiceOver, light/dark, Reduce Motion, and classic controls. The history link
    shows text and has an accessible
    label; the sheet closes with the shared rounded X button at the top right. Matching local installers use the shared success badge at the
    version artwork's size.
    Older-version downloads stay visible in the sheet; the active family history link reopens the
    sheet after dismissal; Back is disabled while downloading; Cancel first asks for confirmation,
    with the same native confirmation in the main grid, older-version sheet, and details sheet,
    Keep Downloading as the default, and only the confirmed action cancels (clicking
    active artwork does nothing). Indeterminate and cancellation feedback is
    centered over the artwork inside the ring, and Cancel is disabled during cancellation. Scrolling
    is available only when content exceeds the viewport and its indicator is visible. Keep the last
    100 lines of download command output in memory and show them beneath installer details in an
    automatically opened, dismissible download sheet. Closing the sheet leaves acquisition running;
    the active item reopens it. Keep an older-version picker behind the details sheet. A failed
    installer shows a centered retry symbol over its artwork and its item retries that version;
    catalog errors keep their separate refresh action. Left-align the older-version sheet header as
    a bold family name with a gray “Older versions” subtitle; center version/size rows. The download
    sheet places ring/artwork on the left and installer metadata, status, and Cancel on the right. It
    uses one Liquid Glass close control, a collapsible Activity section expanded initially, with a
    generous gap above its divider that contracts around warnings, a taller sheet when a warning
    needs space, a scrollable Activity area that does not clip output, smooth progress/artwork/warning
    transitions, fade-only collapse, and a
    single leading-aligned error callout
    without duplicate grid text while the sheet is open. It
    omits status copy redundant with progress. On success, it replaces the ring with an enlarged
    shared success badge through a scale/fade transition, using a crossfade under Reduce Motion.
  - Verify: Run `AssistantFlowUITests`; inspect the live view and previews in light/dark and classic
    appearances; verify Reduce Motion, the older-version sheet, stable item heights, and VoiceOver labels.
  - Files: `Relente/Views/DownloadView.swift`, `Relente/Views/DownloadDetailsSheet.swift`,
    `Relente/Components/AvailableInstallerArtwork.swift`,
    `Relente/Views/InstallerView.swift`, `Relente/Components/ProgressRing.swift`,
    `Relente/Services/InstallerAcquisitionService.swift`, `Relente/Services/LiveInstallerAcquisitionService.swift`,
    `Relente/App/Assistant.swift`, `Relente/Resources/Localizable.xcstrings`,
    `RelenteUITests/AssistantFlowUITests.swift`
  - Dependencies: Task 7
  - Scope: Medium
  - [x] The Download main view now uses shared `PickLayout`, `PickItemSize` and the flow's sliding
    selection: four options remain regular in a row; five or more use five compact columns. The
    older-version sheet retains its agreed one/two-column arrangement. Progress emphasizes a larger
    number and smaller gray percent sign. The Cancel control opens a localized confirmation with
    Keep Downloading as its safe default. Debug and universal Release builds, `build-for-testing`,
    strict lint and `PickLayoutTests` pass. Live light-appearance validation of the grid, older-
    version sheet, and downloaded older-version selection is recorded below. Dark/classic,
    Reduce Motion, VoiceOver, and the UI-test runner remain unverified.
  - [x] Choosing a downloaded installer keeps Download visible with the local installer selected;
    Continue advances to USB Drive with the normal animated forward transition.
  - [x] The selected local installer now marks shared artwork on Download so its icon flies into
    USB Drive; the older-version sheet header is left-aligned with a bold family name and gray subtitle.
  - [x] Download details center the visible ring-and-metadata group; percentage digits use the
    shared Reduce Motion-aware rolling counter. A downloaded exact match in an older release is
    marked on the family history control, and its Finder artwork has a version placeholder while loading.
  - [x] On 2026-10-31, the latest Xcode Debug build loaded Apple's live catalog. Monterey 12.7.4
    showed its actual installer artwork and success badge in the older-version sheet; closing the
    sheet kept the older-download indicator in the grid, and Continue advanced to USB with
    Monterey 12.7.4 and its actual installer size. No USB was connected.
  - A later Xcode build preloads local installer icons in Download and avoids showing the version
    placeholder while a local icon is loading. The Monterey older-version sheet opened with its
    local installer available; the initial visual transition was not timed or verified. Strict
    lint passed. In the preceding Xcode test run, the unit-test group passed, while UI tests
    reported duplicate Tahoe download accessibility elements and a missing older-versions control;
    the UI run was stopped before completion. Keep the remaining UI and accessibility checks open.

### Checkpoint: User flow

- [x] Sample UI flow covers empty Installer, Download navigation and continuation with the
  acquired installer; service tests cover progress, cancellation and failure recovery.
- [x] Build succeeds and the USB screen uses the selected installer's size for capacity checks.

## Phase 4: Quit handling and product integration

- [ ] Task 9: Coordinate normal app termination with the acquisition service
  - Acceptance: A normal quit during a download shows the agreed native alert and keeps Relente
    open while the user waits; force quit/crash paths fail closed on relaunch.
  - Verify: Build and run the app from Xcode and manually verify the alert during a real download;
    verify the app remains open and the download continues after choosing to wait.
  - Files: `Relente/App/RelenteAppDelegate.swift`, `Relente/App/RelenteApp.swift`,
    `Relente/Services/InstallerAcquisitionService.swift`,
    `RelenteTests/InstallerAcquisitionServiceTests.swift`
  - Dependencies: Tasks 6–8
  - Scope: Medium
  - The earlier quit-to-cancel implementation was replaced with the owner's requested wait alert.
    Xcode compiled it, but the alert during a real active download remains unverified.

- [ ] Task 10: Validate retained installer integration and update product documentation
  - Acceptance: A completed app is detected, selected, reusable after relaunch, and accepted by the
    existing creation flow; docs describe the shipped Download state and retention behavior.
  - Verify: Run full unit tests and `AssistantFlowUITests`; complete a controlled Apple download,
    restart Relente, reuse it, and walk through USB selection/creation. Run strict lint and the
    universal Release build.
  - Files: `RelenteUITests/AssistantFlowUITests.swift`, `docs/product.md`, `README.md`, `BUILDING.md`
  - Dependencies: Tasks 7–9
  - Scope: Medium
  - [x] Updated `docs/product.md` to describe the current Download flow, catalog refresh, retention,
    cancellation controls and the still-unverified system transaction behavior.
  - The 27.2 fetch stayed at scanning while system logs showed an indistinguishable 27.2
    `DownloadAndPrepareUpdate` transaction. The foreground CLI was stopped; no installer app
    appeared and no cache was removed. That attempt remains inconclusive and was not retried.
  - On 2026-10-30, the signed app on macOS 27.2 started a fresh 27.2 fetch and showed observed
    progress through 68%. The owner cancelled it before completion; no installer appeared in
    `/Applications`. This run does not verify retention or the service cancellation guarantee.
  - On 2026-10-31, Monterey 12.7.4 (12.41 GB) downloaded from the app. `softwareupdated` logged
    network resets and retried the package; Relente then received `Install finished successfully`
    at 90%. The app appeared in `/Applications`, reopened as **Use macOS Monterey 12.7.4** after a
    normal quit, and Continue advanced to USB Drive with the correct installer size. Launch
    Services would not reopen the replaced app (`kLSNoExecutableErr`), so this relaunch check used
    the installed app's executable directly. No USB drive was connected, so creation and erase were
    not attempted. Keep Task 10 open until standard app launch and the remaining integration checks
    can be verified.
  - On 2026-10-31, the Xcode-launched build also reused the locally available Monterey 12.7.4 from
    the older-version sheet and advanced to USB Drive with its actual size. No USB was connected;
    creation and erase were not attempted.

### Checkpoint: Integration

- [x] The complete unit-test suite passes.
- [ ] The updated older-version sheet interaction passes in `AssistantFlowUITests`; its runner
  exits before bootstrapping with `signal kill` in this environment, so that change remains
  unverified by UI automation. Retried outside the sandbox on 2026-10-30; the runner still exited
  before establishing its connection. The signed live app did load Apple's real catalog and open
  the older-version sheet; accessibility inspection confirmed the visible version actions and Done
  control. Appearance variants and full VoiceOver review remain open.
- [x] Strict lint and universal Release build pass (2026-10-30; Release build was rerun outside the
  sandbox after an initial asset-catalog export failure).
- [x] Local installer selection still works offline; helper safety checks are unchanged.
- [x] Product documentation matches the implemented flow and records the outstanding cancellation
  guarantee validation.

- A signed development build for team `99TLZFAX53` is available at `/Applications/Relente.app`.
  The prior signing blocker was resolved; manual live acquisition and reuse still need validation.
  Do not substitute sample data for the manual live check.

## Phase 5: Incomplete installer recovery

- [ ] Task 11: Move confirmed incomplete installers with a constrained helper operation
  - Acceptance: Keep the existing candidate scan, final identity/snapshot revalidation,
    item-specific confirmation and active-download guard. Add one typed helper endpoint deriving
    the caller UID from authenticated XPC, validating the exact incomplete Apple installer app
    directly under `/Applications`, and moving it to that user's Trash. Reject arbitrary paths,
    symlinks in the app path, Info.plist or required files, complete/changed apps, unsafe Trash
    locations, and active helper operations; allow Apple's normal internal framework symlinks and
    fingerprint them with the same algorithm as the app. The review sheet sizes to its candidate
    rows, keeps its informational note at the bottom with the accent-blue info icon, and scrolls
    only when the candidate list exceeds its cap. Do not expose generic filesystem operations or
    touch system-managed caches.
  - Verify: Tests cover success, rejected paths and changed candidates, failure propagation, and
    active-download prevention. Manually confirm a root-owned incomplete app appears in the
    caller's Trash and rescanning removes it. Ensure complete installers are never offered.
  - Files: `Shared/HelperProtocol.swift`, `Shared/IncompleteInstallerTrashOutcome.swift`,
    `Shared/InstallerBundleSnapshot.swift`,
    `RelenteHelper/HelperListener.swift`, `RelenteHelper/HelperRequestHandler.swift`,
    `Relente/Services/LiveHelperClient.swift`, `Relente/Models/IncompleteInstaller.swift`,
    `Relente/Services/InstallerAcquisitionService.swift`,
    `Relente/Services/LiveInstallerAcquisitionService.swift`,
    `Relente/Services/SampleInstallerAcquisitionService.swift`, `Relente/App/Assistant.swift`,
    `Relente/Views/AssistantView.swift`, `Relente/Views/DownloadView.swift`,
    `Relente/Views/IncompleteInstallerRecoveryView.swift`,
    `Relente/Resources/Localizable.xcstrings`, `RelenteTests/LiveInstallerAcquisitionServiceTests.swift`,
    `RelenteTests/HelperRequestHandlerTests.swift`, `RelenteTests/HelperContractTests.swift`,
    `RelenteTests/InstallerReaderTests.swift`, `Relente/Components/FileIcon.swift`,
    `SECURITY.md`
  - Dependencies: Tasks 3, 5, 6, 10
  - Scope: Medium

## Final gate: Cancellation guarantee

- [ ] Task 12: Verify normal-quit cancellation on the available macOS version
  - Acceptance: On the available macOS version, confirm the full service-owned download transaction stops before
    normal app termination and no partial installer becomes selectable. Determine whether partial
    data can be attributed to this fetch and removed after confirmed stop; never clear a shared
    Software Update cache or touch data while its transaction may still be active.
  - Verify: Controlled manual download, Cancel and normal-quit checks; inspect application detection
    and available system evidence after CLI exit. Document what partial data remains and whether its
    ownership and cleanup can be proven. Document that other supported macOS versions were
    unavailable for testing.
  - Files: `specs/011-installer-acquisition/spec.md` (record only evidence or owner-approved
    behavior changes)
  - Dependencies: Tasks 1–11
  - Scope: Small
  - On 2026-10-31, a live Xcode run fetched Big Sur 11.7.11 (12.41 GB). A normal Quit attempt did
    not visibly cancel it: progress continued from 7% to 9% while Relente remained open. Explicit
    in-app cancellation at 10% changed the UI to “Download cancelled” and the grid did not offer
    the result as a local installer. This does not establish what the normal Quit action did or
    prove the system transaction stopped; no cache or partial data was inspected or removed.
    As a control, choosing Quit while idle ended the Xcode run; I then relaunched the same scheme
    from Xcode. This narrows the discrepancy to the active-download case, but does not identify
    why its cancellation request failed.
  - In a later Xcode run, the Big Sur download was at 40%; closing its detail sheet left it active
    in the grid. Choosing Quit ended the Xcode-launched Relente process, but Activity Monitor still
    showed the `softwareupdate` command (PID 6220, user `afraidias`). Sending the normal process
    exit from Activity Monitor did not remove it. Force Quit was then requested; the refreshed
    process list no longer showed PID 6220. The system `softwareupdated` daemon remained, which alone
    does not prove whether its transaction continued. Therefore normal app termination has not been
    shown to stop the command or transaction; only Force Quit removed the CLI process. No shared
    cache or partial installer was inspected or deleted. Keep this gate open and return to the owner
    before declaring Spec 011 complete.
  - The runner now sends SIGTERM, waits two seconds, and sends SIGKILL to its own `softwareupdate`
    process if it is still running. In an Xcode-launched live Big Sur 11.7.11 run, normal Quit with
    the details sheet closed logged the cancellation request and completion before Xcode reported
    Relente finished. After refreshing Activity Monitor's process filter, the `softwareupdate` CLI
    was absent; `softwareupdated` remained. Relaunching from Xcode and loading Apple's live catalog
    showed Big Sur as **Download**, not **Use**, so no complete installer was exposed. This does not
    prove whether `softwareupdated` continued an internal transaction, nor identify or authorize
    cleanup of partial data. The final gate remains open.
  - Console later showed Apple product `047-32248` (Big Sur 11.7.11) reach 100% at 12,413,724,527
    bytes after 2,281 seconds cumulative download time. `suhelperd` copied `InstallAssistant.pkg`
    and its integrity data into `/Library/Updates/047-32248`; `softwareupdated` then failed package
    installation with `PKInstallErrorDomain` code 100 (authorization required) and removed the
    local product record. Because this fetch reused earlier partial progress and the log timestamps
    do not establish precisely when the normal Quit happened relative to completion, this does not
    prove Quit caused the download to finish. It does confirm that killing the CLI alone is not
    evidence the Apple-managed transaction was cancelled. No cache or package was manually
    inspected or removed.
  - Official-interface research on 2026-10-31: Apple's user documentation recommends
    `softwareupdate --fetch-full-installer --full-installer-version` to obtain full installers
    ([Apple Support](https://support.apple.com/en-us/102662)); the local `softwareupdate` manual
    lists no cancellation option for this command. Apple's documented MDM software-update
    management is a separate, supervised-device workflow for scheduling OS updates, not a local
    API for cancelling a full-installer fetch; older MDM schedule commands are removed in favor of
    declarative management ([Schedule OS Update](https://developer.apple.com/documentation/devicemanagement/schedule-os-update-command),
    [software update enforcement](https://developer.apple.com/documentation/devicemanagement/phases-of-software-update-enforcement)).
    No Apple-documented local cancellation API for `--fetch-full-installer` was found. Do not kill
    `softwareupdated` or clear shared update caches as a substitute: that is not a documented,
    transaction-scoped cancellation mechanism and could affect unrelated system updates. With the
    official CLI path, current evidence only supports terminating Relente's child process; it does
    not establish cancellation of work owned by Apple's update services. Keep the final gate open.
  - A further live Xcode run on 2026-10-31 requested Big Sur 11.7.11. Console identified product
    `047-32248` beginning its installer-package download at 19:02:31 local time. Relente showed 2%
    and the owner-authorized cancellation was confirmed around 19:04; the sheet then said the
    download was cancelled. The `softwareupdate` CLI was subsequently absent from Activity
    Monitor. After cancellation, the shared `softwareupdated` process's cumulative received-byte
    counter was observed at 164.2 MB and later at 1.07 GB; this counter is daemon-wide and cannot
    attribute those bytes to Big Sur rather than another Apple update. Console's product-filtered
    view did not establish a post-cancellation terminal event for this fetch. The observation
    therefore does not prove either that the transfer continued or that it stopped. No shared
    cache or process belonging to the system was modified.
    The owner subsequently reported no other update was in progress. A later observation showed
    the same `softwareupdated` PID at 2.14 GB received. Alongside the product's start event and the
    absence of another user-known update, this strongly suggests Big Sur continued after Relente
    reported cancellation; daemon-wide counters alone still do not identify the bytes' source.
  - Subsequent Activity Monitor inspection of that same `softwareupdated` PID showed the
    product-specific `047-32248` `InstallAssistant.pkg.partial` file among its open files, after
    Relente had reported cancellation. System Settings reported macOS 27.2 up to date and showed
    no control for the Big Sur installer fetch. This connects the continuing daemon to the same
    partial package, although an open file alone does not establish its exact transfer state.
    Community maintenance guidance mentions restarting the entire daemon, but it is not a
    transaction-scoped cancellation and is not accepted as a safe in-app mechanism.
  - A later read-only system log check showed `softwareupdated` reporting at 19:45:34 local time
    that product `047-32248` failed to download `InstallAssistant.pkg` with `PKDownloadError`
    code 14 and was retrying. This confirms that Apple's Big Sur transaction continued after the
    19:04 cancellation shown by Relente. A new SIGINT trial must not start while it may still be
    active, because the attempts would be indistinguishable. The system partial file could not be
    inspected by the current user; it was not modified.
  - On 2026-11-02, historical logs showed further retries for product `047-32248` on 2026-10-31
    and 2026-11-01; at 13:01:55 on November 1 its downloader stopped with a download error.
    Thus this particular operation ended in failure more than 17 hours after Relente reported
    cancellation. No active product event was found in the last 30 minutes on November 2. The
    proposed service-restart trial was not performed: there was no confirmed active test download,
    and checking noninteractive administrator authorization reported that a password is required.
  - SIGINT trial plan: after the earlier transaction reaches an observed terminal state, start a
    fresh installer fetch from the Xcode-launched app, record the product and cancellation time,
    send SIGINT to that fetch's CLI without immediate SIGTERM/SIGKILL escalation, then observe the
    CLI, product-specific events, network activity and open partial file. A lack of activity in a
    short window is not proof of termination. Keep other updates and shared caches untouched.
  - On 2026-11-02, after the previous transaction ended in error, an Xcode-launched build temporarily
    sent SIGINT alone for cancellation. Big Sur 11.7.11 (`047-32248`) began downloading at 16:39:46;
    the user-authorized cancellation was confirmed at approximately 16:40:23 after the UI reached
    62%. The CLI exited and Relente displayed "Download cancelled." Subsequent `nettop` samples of
    the same `softwareupdated` PID showed received bytes increasing from 7.4 MB to 10.75 MB, then
    from 23.57 MB to 28.75 MB in later one-second samples. Product-specific logs showed the start
    but no terminal event in the observation window. This is strong evidence that SIGINT alone
    did not stop the service-owned work; daemon-wide counters cannot by themselves identify a
    transfer. No shared cache or system daemon was modified. The temporary runner change was
    reverted after the experiment; the cancellation guarantee remains unresolved.
    A later product-specific log check established the outcome: at 16:55:52 the downloader
    stopped and the product moved from downloading to waiting to install and then installing.
    Package installation failed at 16:55:53 with `PKInstallErrorDomain` code 100 (authorization
    required), and macOS removed the local product record. Therefore, for this attempt, SIGINT
    stopped Relente's CLI but did not stop Apple's full-installer download.
  - If the guarantee cannot be established, stop and return to the owner before declaring this
    feature complete.
