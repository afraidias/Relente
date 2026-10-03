# Tasks: 008 · System helper, XPC and security checks

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

Test command (unit tests):
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests`
Lint: `xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests`

## Phase 1: Project and shared rules

- [x] Task 1: Xcode setup (done by the owner in Xcode, step by step)
  - Acceptance: a `Shared/` synchronized folder belongs to the `Relente` and `RelenteHelper`
    targets; `RelenteHelper` is a Command Line Tool target (Swift 6, `MainActor` default
    isolation, approachable concurrency, Hardened Runtime, bundle identifier
    `com.afraidias.Relente.Helper`, Info.plist embedded in the binary, team `99TLZFAX53`) whose
    `main.swift` only logs and exits; the app depends on it and copies it to `Contents/MacOS/`, and
    copies `com.afraidias.Relente.Helper.plist` to `Contents/Library/LaunchDaemons/` (not to
    Resources); CI lints the new folders and checks the helper's architectures; AGENTS.md's lint
    command and BUILDING.md's project layout list the new folders.
  - Verify: Debug and universal Release builds; `lipo -archs` on the embedded helper shows arm64
    and x86_64; `codesign -dv` on it shows identifier `com.afraidias.Relente.Helper`; the plist is
    where it should be; lint passes.
  - Files: `Relente.xcodeproj/project.pbxproj`, `RelenteHelper/main.swift`,
    `Config/com.afraidias.Relente.Helper.plist` (outside the synchronized `Relente/` folder, so it
    isn't copied as a resource), `Shared/HelperProtocol.swift`, `.github/workflows/ci.yml`,
    `AGENTS.md` (+ the lint command in `BUILDING.md`, `CONTRIBUTING.md`, the PR template and the
    pre-commit hook; `BUILDING.md` layout table)

- [x] Task 2: Move the drive rules to `Shared/`
  - Acceptance: `DiskDescription` and the USB/SD and boot-disk rules (`DiskRules`) live in
    `Shared/`, together with the DiskArbitration dictionary mapping; `DriveCatalog` uses them;
    `Drive` carries a `DiskFingerprint` (media UUID, serial number, capacity); behavior unchanged.
  - Verify: existing `DriveCatalogTests` pass, calling `DiskRules` instead of
    `DriveCatalog.isCandidate`; a new test for the fingerprint built from a description. The
    DiskArbitration reading (`DiskDescriber`) moved to `Shared/` too, for the helper.
  - Files: `Shared/DiskDescription.swift`, `Shared/DiskRules.swift`, `Shared/DiskFingerprint.swift`,
    `Relente/Models/DriveCatalog.swift`, `Relente/Models/Drive.swift`

- [x] Task 3: `EraseRequestCheck` (test-driven)
  - Acceptance: identifier regex (accepts `disk4`, rejects `disk4s1`, `disk`, `../disk4`,
    `disk4 `, ""); drive rules plus 8 GB–2 TB; fingerprint matches only when every part is equal
    and refuses a drive with neither media UUID nor serial number. Each returns the matching
    `FormatOutcome`.
  - Verify: `EraseRequestCheckTests`, `DiskFingerprintTests`.
  - Files: `Shared/EraseRequestCheck.swift`, `Shared/FormatOutcome.swift`,
    `RelenteTests/EraseRequestCheckTests.swift`, `RelenteTests/DiskFingerprintTests.swift`

- [x] Task 4: Protocol and fixed values
  - Acceptance: `HelperProtocol` (`protocolVersion`, `format`, `cancel` with simple types only),
    Mach service name and version; `CodeSigningRequirement` for app and helper (identifier + Team
    ID); `DiskutilCommand` (`/usr/sbin/diskutil`, `["eraseDisk", "JHFS+", "MyVolume", "GPT",
    bsdName]`); `EraseRight` (name and rule: admin, not shared, timeout 0).
  - Verify: `HelperContractTests` (requirement strings, diskutil arguments, right's rule).
  - Files: `Shared/HelperProtocol.swift`, `Shared/CodeSigningRequirement.swift`,
    `Shared/DiskutilCommand.swift`, `Shared/EraseRight.swift`, `RelenteTests/HelperContractTests.swift`

- [x] Task 5: `FormatPipeline` (test-driven)
  - Acceptance: with fake authorization, disk reader and formatter: a missing or refused
    authorization returns `notAuthorized` before the disk is read; checks run in the spec's
    order; a disk that disappears returns `driveDisconnected`; the formatter runs only when all
    pass; a second request while one runs returns `busy`; cancel reaches the formatter.
  - Verify: `FormatPipelineTests`.
  - Files: `Shared/FormatPipeline.swift`, `RelenteTests/FormatPipelineTests.swift`

### Checkpoint A: Rules
- [x] Unit tests and lint pass; Debug and universal Release build with no warnings; the Release
  app contains the universal helper and the launchd plist.

## Phase 2: The helper runs, and Permissions installs it

- [x] Task 6: Helper live pieces
  - Acceptance: listener on the Mach service with `setConnectionCodeSigningRequirement`; the
    exported object runs `FormatPipeline`; live authorization checker (creates the right if
    missing, checks without interaction), disk reader (DiskArbitration), formatter (`Process`,
    terminated on cancel or when the connection drops); quits after 60 s idle; logs under
    `helper` without fingerprints or serial numbers.
  - Verify: builds with no warnings (checked running at Checkpoint B).
  - Files: `RelenteHelper/main.swift`, `RelenteHelper/HelperListener.swift`,
    `RelenteHelper/HelperRequestHandler.swift`, `RelenteHelper/LiveAuthorizationChecker.swift`, `RelenteHelper/LiveDiskReader.swift`,
    `RelenteHelper/LiveDiskFormatter.swift`

- [x] Task 7: Helper service and the Permissions step (test-driven on the assistant)
  - Acceptance: `HelperService` live (`SMAppService`) and sample; `AssistantStep.permissions`
    without a step number; the assistant starts on Permissions unless the helper is ready;
    install, refresh, continue (crossfade) and uninstall (crossfade back, installer kept, not
    while creating); `-sampleHelper notInstalled`; unit tests use the sample service.
  - Verify: `AssistantHelperTests`.
  - Files: `Relente/Services/HelperService.swift`, `Relente/Services/LiveHelperService.swift`,
    `Relente/Services/SampleHelperService.swift`, `Relente/Models/AssistantStep.swift`,
    `Relente/App/Assistant.swift` (+ `RelenteApp.swift` wiring, `RelenteTests/AssistantHelperTests.swift`)

- [x] Task 8: Permissions screen
  - Acceptance: option E of the canvas (spec Decision 9): header, the app icon as hero with a
    halo and `StatusBadge` per status, the status line and "Waiting for approval…", the blue
    authorization `Callout`, and one footer button that is the default action; refresh every 2 s
    and on becoming active; VoiceOver announces status changes; `AuthenticationMethod` picks
    `touchid`/`lock` and the texts; previews for every status (light, dark, classic); strings in
    English and Spanish. *(A first version with Settings-style rows was replaced at the owner's
    request; `WarningCallout` became `Callout` with a warning and an info tone, and Error's badge
    became the shared `StatusBadge`.)*
  - Verify: `AuthenticationMethodTests`; previews; screen reviewed at Checkpoint B.
  - Files: `Relente/Views/PermissionsView.swift`, `Relente/Components/Callout.swift`,
    `Relente/Components/StatusBadge.swift`, `Relente/Models/AuthenticationMethod.swift`,
    `Relente/Views/AssistantView.swift` (+ `Localizable.xcstrings`, `ReviewView.swift`,
    `CreatingView.swift`)

- [x] Task 9: Uninstall menu item, and the first XPC call
  - Acceptance: "Uninstall System Helper…" after About, disabled while creating; the alert
    ("Cancel" answers Return and Esc, "Uninstall" click only); failure alert. `HelperClient` with
    `protocolVersion` over a connection with `setCodeSigningRequirement`, called when Permissions
    reaches Ready.
  - Verify: builds; checked by hand at Checkpoint B.
  - Files: `Relente/App/AssistantCommands.swift`, `Relente/Views/AssistantView.swift`,
    `Relente/Views/UninstallHelperSheet.swift`, `Relente/Components/AlertSheet.swift` (spec 004's
    alert-like sheet, now shared with "Stop"), `Relente/Services/HelperClient.swift`,
    `Relente/Services/LiveHelperClient.swift` (the whole client: version, format and cancel),
    `Relente/Resources/Localizable.xcstrings`

### Checkpoint B: Helper installed (manual, with the owner)
- [x] Install → Needs approval → Open Settings… → turn on → Ready within 2 s → Continue; the
  `helper` log shows the version request accepted. *(launchd runs it on demand; "Connection
  accepted" and "Helper ready; connection works" in the log.)*
- [x] An ad-hoc signed program is refused (rule 2). *(A small unsigned program calling
  `protocolVersion` got "Couldn't communicate with a helper application"; the helper logged
  "Dropping check-in message due to code signing requirement", status -67050. The "cannot open
  file … DetachedSignatures" line the Security framework logs while checking signatures is
  harmless.)*
- [x] Turning Relente off in System Settings on Review: back to Permissions within 2 s, with the
  installer and drive still chosen after turning it on again and pressing Continue.
- [x] Uninstall from the menu: Return and Esc cancel; "Uninstall" removes it from Login Items and
  Permissions is shown.
- [x] Owner reviews Permissions (light, dark, classic, VoiceOver, Reduce Motion). *(Checked by
  the agent with UI-test screenshots in Spanish: light and classic in the real app, dark through
  renders; VoiceOver's order from the accessibility tree: title, subtitle, status line, "Waiting
  for approval…", callout, button. The line under the hero now keeps its space in every status,
  so the hero no longer moves up by 10 pt on "Needs approval". Reduce Motion: Permissions only
  crossfades. Dark mode in the real app checked by the owner.)*

## Phase 3: Erase and Create

- [ ] Task 10: Authorizer
  - Acceptance: `EraseAuthorizer` live (dialog in a `@concurrent` function, with Relente's own
    localized prompt, `.cancelled` when cancelled) and sample. (`HelperClient.format` and `cancel`
    were built in Task 9; a `nil` reply or a version that still differs after one reconnection
    becomes `helperUnavailable` in Task 11.)
  - Verify: builds; sample used in tests; checked at Checkpoint C.
  - Files: `Relente/Services/EraseAuthorizer.swift`, `Relente/Services/LiveEraseAuthorizer.swift`,
    `Relente/Resources/Localizable.xcstrings`

- [ ] Task 11: Format, then simulate (test-driven where it's logic)
  - Acceptance: `CreationService.simulation` (`.everything`, `.afterFormat`) replaces
    `isSimulated`; `HelperCreationService` (Debug) formats through the client with no percentage,
    then continues the simulated timeline from Copy, and maps outcomes to reasons; four new
    `CreationFailure.Reason`s with English and Spanish texts; "Try Again" goes to USB Drive for
    `driveChanged` and `driveNotAllowed`; the label shows "SIMULATION · Only the format is real".
  - Verify: `HelperCreationServiceTests` (with a fake client), `CreationFailureTests`,
    `AssistantNavigationTests` for "Try Again".
  - Files: `Relente/Services/CreationService.swift`, `Relente/Services/HelperCreationService.swift`,
    `Relente/Models/CreationFailure.swift`, `Relente/Components/SimulationLabel.swift`,
    `RelenteTests/HelperCreationServiceTests.swift`

- [ ] Task 12: Erase and Create asks first
  - Acceptance: `eraseAndCreate()` is async: helper not ready → the "System Helper Is Off" alert
    ("Open Settings…" default, "Cancel" Esc); authorization cancelled → stays on Review with the
    checkbox checked; otherwise Creating with the authorization; Review shows `touchid` or `lock`;
    `RelenteApp` wires `HelperCreationService` in Debug without sample data.
  - Verify: `AssistantEraseTests` with sample authorizer and helper service; full unit suite.
  - Files: `Relente/App/Assistant.swift`, `Relente/App/RelenteApp.swift`,
    `Relente/Views/ReviewView.swift`, `Relente/Views/AssistantView.swift`,
    `RelenteTests/AssistantEraseTests.swift`

### Checkpoint C: Real erase (manual, with the owner's USB drive)
- [ ] Authorization asked (note whether Touch ID is offered; if not, apply the spec's fallback);
  cancelling leaves Review; accepting erases as "MyVolume" (Mac OS Extended (Journaled), GPT) and
  ends on Done with the new label.
- [ ] Reformatting the drive between Review and Erase is refused as changed; unplugging during
  Format fails as disconnected; Stop during Format.
- [ ] Helper turned off in System Settings → the alert on Erase and Create.

## Phase 4: Finish

- [ ] Task 13: UI test and docs
  - Acceptance: the UI test walks Permissions with `-sampleHelper notInstalled` and then the whole
    flow; `docs/product.md` (Permissions, label, `lock`, menu item), SECURITY.md (uninstalling),
    BUILDING.md (helper, approving it while developing, `-sampleHelper`), README roadmap step 6
    checked; spec Status Done and index.
  - Verify: full test suite including UI tests; lint.
  - Files: `RelenteUITests/RelenteUITests.swift`, `docs/product.md`, `SECURITY.md`,
    `BUILDING.md`, `README.md` (+ `specs/008-system-helper/spec.md`, `specs/README.md`)

### Checkpoint D: Definition of Done
- [ ] Full test suite, lint, Debug and universal Release builds with no warnings; light and dark,
  VoiceOver and Reduce Motion on Permissions, the alerts and the new failures; every acceptance
  criterion of the spec checked or recorded in Open items.
