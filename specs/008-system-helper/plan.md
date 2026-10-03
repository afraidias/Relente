# Implementation Plan: 008 · System helper, XPC and security checks

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

## Overview
A new command-line target, `RelenteHelper`, is embedded in the app and registered as a launch
daemon with `SMAppService`. App and helper share a `Shared/` folder compiled into both: the XPC
protocol, the drive rules moved from spec 007, and every security check as a pure function or as
a pipeline with injected dependencies, so all of it is unit-tested in `RelenteTests` without the
real helper. The app gains a helper service (install status, register, unregister), an
authorizer (the Authorization Services dialog) and an XPC client. The assistant gains the
Permissions step and, in Debug with real drives, a creation service that formats through the
helper and then simulates the rest. The UI changes are the Permissions screen, the `lock`/`touchid`
choice, the helper-off alert, the new failure reasons, the simulation label's second text and the
"Uninstall System Helper…" menu item.

## Architecture Decisions

### Targets and files
- **`Shared/`** (repo root, synchronized folder, member of the `Relente` and `RelenteHelper`
  targets). `RelenteTests` reaches it through `@testable import Relente`, as today. Contents:
  - `HelperProtocol.swift`: the `@objc` XPC protocol (`protocolVersion`, `format`, `cancel`),
    the Mach service name, `HelperProtocol.version`.
  - `FormatOutcome.swift`: `Int`-backed enum the helper replies with (`formatted`,
    `notAuthorized`, `invalidIdentifier`, `driveNotAllowed`, `driveChanged`, `driveDisconnected`,
    `formatFailed`, `busy`).
  - `DiskDescription.swift`, `DiskRules.swift` (moved from `Models/` and from
    `DriveCatalog.isCandidate`): which disks are USB drives or SD cards, boot disk detection, and
    the DiskArbitration dictionary → `DiskDescription` mapping. `DriveCatalog` keeps grouping and
    naming, and calls `DiskRules`.
  - `DiskFingerprint.swift`: media UUID, serial number, size; `matches(_:)` and `isIdentifiable`.
  - `EraseRequestCheck.swift`: identifier regex `^disk[0-9]+$`, size range 8 GB–2 TB, and the
    whole check in the spec's order.
  - `FormatPipeline.swift`: the helper's request handling with protocols for its three outside
    pieces (`AuthorizationChecking`, `DiskReading`, `DiskFormatting`). Order: authorization →
    identifier → read disk → drive rules → fingerprint → format. One request at a time.
  - `CodeSigningRequirement.swift`: the two requirement strings
    (`identifier "…" and anchor apple generic and certificate leaf[subject.OU] = "99TLZFAX53"`).
  - `DiskutilCommand.swift`: `/usr/sbin/diskutil` and
    `["eraseDisk", "JHFS+", "MyVolume", "GPT", bsdName]`.
  - `EraseRight.swift`: the right's name and its rule (class user, group admin, `shared` false,
    `timeout` 0).
  The pipeline is also compiled into the app, which doesn't use it; the alternative (a helper test
  target) is more Xcode setup for no gain in safety.
- **`RelenteHelper/`** (new target, macOS › Command Line Tool, Swift 6, `MainActor` by default,
  Hardened Runtime, bundle identifier `com.afraidias.Relente.Helper` with its Info.plist embedded
  in the binary, so it signs with that identifier). Only the live pieces, which can't run in
  tests: `main.swift` (listener on the Mach service, `setConnectionCodeSigningRequirement`, run
  loop), `HelperListener.swift` (accepts connections, quits after 60 s idle),
  `HelperRequestHandler.swift` (the exported object, calls the pipeline),
  `LiveAuthorizationChecker.swift` (creates the right if missing with `AuthorizationRightSet`,
  checks it with `AuthorizationCreateFromExternalForm` + `AuthorizationCopyRights` without
  interaction), `LiveDiskReader.swift` (DiskArbitration, using the shared mapping),
  `LiveDiskFormatter.swift` (`Process`, cancel by `terminate()`, also when the connection is
  invalidated).
- **`Config/com.afraidias.Relente.Helper.plist`**: the launchd plist (`Label`,
  `BundleProgram` = `Contents/MacOS/RelenteHelper`, `MachServices`,
  `AssociatedBundleIdentifiers` = `com.afraidias.Relente`), copied to
  `Contents/Library/LaunchDaemons/` by a Copy Files phase. It lives outside the synchronized
  `Relente/` folder, which would copy it as a resource. The helper binary is copied to `Contents/MacOS/` by another Copy Files phase; the
  app target depends on the helper target.

### App: services
- **`HelperService`** (`Services/HelperService.swift`): `var status: HelperStatus`,
  `register() throws(HelperError)`, `unregister() async throws(HelperError)`,
  `openSettings()`. `HelperStatus`: `.notInstalled`, `.needsApproval`, `.ready`,
  `.failed(HelperError)`. `LiveHelperService` wraps `SMAppService.daemon(plistName:)`;
  `SampleHelperService` starts in a given status and, on `register()`, moves to `.needsApproval`
  and then `.ready` after a moment (for `-sampleHelper notInstalled`).
- **`EraseAuthorizer`** (`Services/EraseAuthorizer.swift`): `authorize() async throws(AuthorizationError) -> Data`
  (the external form). Live: `AuthorizationCopyRights` with interaction in a `@concurrent`
  function (it blocks while the dialog is open); `.cancelled` when the user cancels. Sample:
  returns empty data at once.
- **`HelperClient`** (`Services/HelperClient.swift`): `protocolVersion()`,
  `format(drive:fingerprint:authorization:) async -> FormatOutcome`, `cancel()`. Live: one
  `NSXPCConnection(machServiceName:options: .privileged)` with `setCodeSigningRequirement`,
  replies bridged with `withCheckedContinuation`; an interrupted or invalid connection becomes
  "didn't respond". Reconnects once on a version mismatch.
- **`AuthenticationMethod`** (`Models/AuthenticationMethod.swift`): `.touchID` / `.password`,
  from `(canUseBiometrics, biometryType)` (pure, tested); the live value reads `LAContext`.
  Views get it as data and pick `touchid` or `lock` and the texts.
- **Creation:** `CreationService.isSimulated: Bool` becomes `simulation: Simulation?`
  (`.everything`, `.afterFormat`), which the label shows. `create` takes the authorization data.
  New Debug-only `HelperCreationService`: calls `HelperClient.format`, shows Format with no
  percentage until it replies, maps the outcome to a `CreationFailure.Reason` or continues with
  the simulated timeline from Copy (reusing `SimulatedCreationService.timeline`). Cancelling the
  stream calls `HelperClient.cancel()`.
- **`CreationFailure.Reason`** gains `driveChanged`, `driveNotAllowed`, `formatFailed`,
  `helperUnavailable`, each with title and recovery; `sendsBackToDriveScreen` for the first two.

### App: assistant and views
- **`AssistantStep.permissions`**, with no step number (the footer hides the indicator and the
  shared step indicator draws nothing).
- **`Assistant`** gets `helperService`, `authorizer` (and the client through the creation
  service). Starts on `.permissions` unless the helper is `.ready`. `refreshHelperStatus()` is
  called by the Permissions view every 2 s and when the app becomes active; it posts a VoiceOver
  announcement when the status changes. `installHelper()`, `openHelperSettings()`,
  `continueFromPermissions()` (crossfade to Installer), `uninstallHelper()` (crossfade to
  Permissions, keeps the installer), `canUninstallHelper` (false while creating).
- **`eraseAndCreate()` becomes `async`:** if the creation needs the helper and it isn't
  `.ready`, sets `helperOffAlert`; otherwise asks the authorizer (cancelled → return, still on
  Review, checkbox kept), then moves to Creating as today. `tryAgain()` uses
  `sendsBackToDriveScreen`.
- **App wiring (`RelenteApp`):** sample helper service under tests and with `-sampleData YES`
  (`-sampleHelper notInstalled` changes its start); `HelperCreationService` in Debug without
  sample data; `SimulatedCreationService` with sample data; none in Release.
- **Views:** `PermissionsView` + `PermissionRow` (Settings-style row component) + footer;
  `ReviewFooter` takes the `AuthenticationMethod` and shows the helper-off alert;
  `SimulationLabel` takes the `Simulation`; `AssistantCommands` gains the uninstall item (in
  `CommandGroup(after: .appInfo)`) and its confirmation alert lives in `AssistantView`.

### Project-wide changes the spec approved
- CI and AGENTS.md: the lint command includes `RelenteHelper` and `Shared`; CI's architecture
  check also runs `lipo -archs` on `Contents/MacOS/RelenteHelper`.
- BUILDING.md: the helper target, signing with your own team, approving it in Login Items while
  developing, and how to reset it.

## Task List

### Phase 1: Project and shared rules
- [ ] Task 1: Xcode setup with the owner: `Shared/` folder in both targets, `RelenteHelper`
  target (a stub that logs and exits), embedding and the launchd plist, build settings; lint
  paths in CI and AGENTS.md; CI architecture check.
- [ ] Task 2: Move `DiskDescription` and the drive rules to `Shared/` (`DiskRules`); `Drive`
  carries its `DiskFingerprint`; existing tests stay green.
- [ ] Task 3: `EraseRequestCheck` and `DiskFingerprint` rules (test-driven).
- [ ] Task 4: `HelperProtocol`, `FormatOutcome`, `CodeSigningRequirement`, `DiskutilCommand`,
  `EraseRight` (tested where there's logic).
- [ ] Task 5: `FormatPipeline` with fakes: authorization first, order of checks, one at a time,
  outcomes (test-driven).

### Checkpoint A: Rules
- [ ] Unit tests and lint pass; Debug and universal Release build, helper included, no
  warnings; the Release app contains `Contents/MacOS/RelenteHelper` (arm64 + x86_64) and
  `Contents/Library/LaunchDaemons/com.afraidias.Relente.Helper.plist`.

### Phase 2: The helper runs, and Permissions installs it
- [ ] Task 6: Helper live pieces: listener with code-signing requirement, exported object,
  authorization checker, disk reader, formatter, idle exit.
- [ ] Task 7: `HelperService` (live and sample), `AssistantStep.permissions`, assistant start,
  install, status refresh and uninstall logic; `-sampleHelper` (test-driven on the assistant).
- [ ] Task 8: `PermissionsView`, `PermissionRow`, footer, previews and strings;
  `AuthenticationMethod`.
- [ ] Task 9: "Uninstall System Helper…" menu item and alert; `HelperClient.protocolVersion`
  called when Permissions reaches Ready, to prove the connection.

### Checkpoint B: Helper installed (manual, with the owner)
- [ ] Debug build: Permissions → Install → Needs approval → Open Settings… → turn on → Ready
  within 2 s → Continue. The `helper` log shows the version request accepted.
- [ ] An ad-hoc re-signed copy of the app is refused by the helper (rule 2).
- [ ] Uninstall from the menu: the item disappears from Login Items and Permissions appears.
- [ ] Owner reviews the Permissions screen (light, dark, classic, VoiceOver).

### Phase 3: Erase and Create
- [ ] Task 10: `EraseAuthorizer` (live and sample) and `HelperClient.format`/`cancel`.
- [ ] Task 11: `CreationService.simulation`, `HelperCreationService`, new failure reasons and
  "Try Again" destinations, the label's second text (test-driven where it's logic).
- [ ] Task 12: Assistant's `eraseAndCreate` with authorization and the helper-off alert;
  `touchid`/`lock` on Review; app wiring.

### Checkpoint C: Real erase (manual, with the owner and a USB drive that can be erased)
- [ ] Erase and Create asks for authorization (note whether Touch ID is offered); cancelling
  leaves Review unchanged; accepting erases the drive as "MyVolume" (Mac OS Extended
  (Journaled), GPT) and the run ends on Done with "SIMULATION · Only the format is real".
- [ ] Reformat the drive in Disk Utility between Review and Erase: refused as "changed", nothing
  erased. Unplug during Format: "disconnected". Stop during Format: "You stopped the process."
- [ ] Turning the helper off in System Settings, then Erase and Create: the helper-off alert.

### Phase 4: Finish
- [ ] Task 13: UI test (Permissions with `-sampleHelper notInstalled`, then the whole flow);
  `docs/product.md`, SECURITY.md, BUILDING.md, README roadmap, spec Done, index.

### Checkpoint D: Definition of Done
- [ ] Full test suite, lint, Debug and universal Release builds with no warnings; light and dark,
  VoiceOver and Reduce Motion on Permissions and the new alerts and failures.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Adding a target and Copy Files phases in Xcode is new for the owner, and a wrong setting breaks signing or embedding | High | Task 1 first and alone, step by step in Xcode; then I check the result in `project.pbxproj` and by inspecting the built app (`codesign -dv`, `lipo`, file layout). |
| macOS may not register a daemon from an app outside `/Applications` (e.g. DerivedData), or may keep a stale registration after rebuilding | High | Found at Checkpoint B. If it's needed, BUILDING.md documents copying the Debug app to `/Applications` and resetting with `sfltool resetbtm`. |
| The authorization dialog may not offer Touch ID for a custom right | Medium | Seen at Checkpoint C. If so, `AuthenticationMethod` always returns `.password` and the texts say "password" (spec Edge cases). |
| The right doesn't exist yet when the app asks for it (the helper creates it), so macOS applies its default rule | Medium | The app always calls `protocolVersion` before authorizing, which starts the helper and creates the right. |
| Swift 6 concurrency with XPC callbacks, Authorization Services and DiskArbitration in the helper | Medium | Callbacks bridged with checked continuations; blocking calls in `@concurrent` functions; the helper's state in one actor. No `DispatchQueue`: the helper runs on `RunLoop.main`. |
| The code-signing requirement fails in Debug if the development certificate doesn't carry the Team ID in its OU | Medium | Checked at Checkpoint B with `codesign -d -r-`; the requirement string is one function, easy to adjust. |
| Erasing the wrong disk while testing by hand | High | Checkpoint C uses a drive the owner chooses to erase; the helper's own checks refuse anything that isn't a USB drive or SD card. |

## Rules check
- **Helper security:** rule 1 (three typed calls; `diskutil` with fixed path and argument array;
  no shell), 2 (requirements on both sides; Hardened Runtime and library validation in both
  targets), 3 (the helper re-reads DiskArbitration itself; regex, whole, removable, USB or SD,
  not the boot disk, 8 GB–2 TB, fingerprint right before `diskutil`), 5 (custom right, not shared,
  checked by the helper before reading any disk) and 6 (no networking; `os_log`; uninstall from
  the app) are implemented here and tested in `Shared/`. Rule 4 is roadmap step 7 (spec Open
  items).
- **Architecture:** services are protocols with live and sample implementations injected through
  `init`; models are `nonisolated` `Sendable` value types; `@Observable` assistant; heavy or
  blocking work in `@concurrent` functions; no `DispatchQueue`, no `Task.detached`; one error type
  per service with a user-facing message; logging under `helper`.
- **Platforms:** `SMAppService` needs macOS 13, Authorization Services and `LAContext` exist on
  macOS 14; nothing raises the minimum. No third-party dependencies. CI changes are those the spec
  approved.
- **Tests never talk to the real helper or erase anything:** sample services under tests, with
  `-sampleData YES` and in UI tests.

## Open questions
None. Answered when approving the plan: Task 1 is done in Xcode step by step by the owner, and the
owner has a USB drive that can be erased for Checkpoint C.
