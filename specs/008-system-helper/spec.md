# 008 · System helper, XPC and security checks

**Status:** Done · **Roadmap step:** 6 · **Branch:** `feature/008-system-helper`

## Objective
Give Relente the only part of it that can erase a disk: a small helper that runs as root, which
the app installs with `SMAppService` and talks to over XPC, following the six helper security
rules of AGENTS.md and SECURITY.md. The user installs it once, on a new **Permissions** screen
that only appears while the helper is missing, and can uninstall it from the app's menu.

At the end of this step "Erase and Create" really asks for administrator authorization through Authorization Services (Touch ID when available, otherwise password), and the helper re-validates the drive and **really formats it**; copying the installer,
making it bootable and verifying stay simulated in Debug builds until roadmap step 7, which adds
`createinstallmedia` to the helper. Release builds keep "Erase and Create" disabled until then.

This feature also does the work earlier specs deferred to roadmap step 6: the helper re-validates
the drive (spec 007) and the Permissions screen (spec 007, `docs/product.md`). Authorization Services has now been observed to offer Touch ID on the owner's Mac. The UI indicates Touch ID when LocalAuthentication reports it available, otherwise `lock` for the password fallback; Authorization Services remains the actual authorization and the helper independently verifies its custom right (specs 005 and 006).

Chosen by the owner before writing the spec: real format with the rest simulated; Permissions
about the helper and the authorization, without Full Disk Access; Permissions shown whenever the
helper is missing; uninstalling from the app menu. Permissions' layout was then chosen on a
design canvas (Decision 9).

## Behavior

### The helper
- A separate executable inside the app (`Contents/MacOS/`), registered as a launch daemon with
  `SMAppService.daemon(plistName:)`, its plist in `Contents/Library/LaunchDaemons/`. launchd
  starts it when the app connects and it quits by itself after a while without requests. It never
  runs on its own schedule and does nothing the app doesn't ask for.
- Identifiers: the helper is `com.afraidias.Relente.Helper`, and its XPC Mach service has the
  same name. The XPC protocol, the request and reply types and the checks that the app and the
  helper share live in a shared folder compiled into both targets (the "Shared module" of
  AGENTS.md).
- **API in this step** (helper rule 1), typed, no "run this command" and no shell:

  | Call | What it does |
  | --- | --- |
  | `protocolVersion` | Returns the protocol version, so the app can tell an outdated helper apart (Edge cases). |
  | `format(drive:, fingerprint:, authorization:)` | Verifies the authorization, re-validates the drive, compares its fingerprint, and runs `/usr/sbin/diskutil eraseDisk JHFS+ MyVolume GPT diskN` (fixed path, arguments as an array). Reports progress and the result to the app. |
  | `cancel()` | Stops the format in progress (ends `diskutil`). |

  Roadmap step 7 adds running `createinstallmedia`; nothing else is added to the API.
- **Mutual code-signing checks** (helper rule 2): the helper accepts only connections from the
  app with identifier `com.afraidias.Relente` signed by Team ID `99TLZFAX53`
  (`NSXPCListener.setConnectionCodeSigningRequirement`); the app only talks to a helper with
  identifier `com.afraidias.Relente.Helper` and the same Team ID
  (`NSXPCConnection.setCodeSigningRequirement`). Both targets have Hardened Runtime and library
  validation. The requirement strings are built in one place in the shared code.
- **Re-validation of every request** (helper rule 3), done by the helper on its own, reading
  DiskArbitration itself and never trusting what the app says about the disk:
  1. The identifier matches `^disk[0-9]+$`.
  2. It's a whole disk, removable media, connected over USB or Secure Digital, and external (a
     built-in SD slot counts, as in spec 007). The same rule the app uses to list drives
     (spec 007); it moves to the shared code so both use one implementation.
  3. It isn't the boot disk, and doesn't hold the volume mounted at `/`.
  4. Its size is between **8 GB and 2 TB** (Decisions).
  5. Right before running `diskutil`, its **fingerprint** (media UUID, serial number, size)
     equals the one of the drive the user confirmed on Review. Each part is compared, absent
     included; a drive that has neither a media UUID nor a serial number is refused, since its
     size alone doesn't identify it (Decisions).
- **Administrator authorization** (helper rule 5): a custom Authorization Services right,
  `com.afraidias.Relente.erase`, that asks an administrator to authenticate every time. It
  delegates to macOS's own `authenticate-admin-nonshared` rule: the credential isn't shared with
  other authorizations and lasts 30 s, long enough for the helper to check it; the app makes a new
  authorization for each erase and destroys it afterwards, so the next erase asks again. The
  helper creates the right in the authorization database the first time it runs, and updates it
  when its version changes. The app asks for it (macOS shows its standard dialog, with Touch ID on Macs that have it)
  and sends it to the helper with the request; the helper checks it again, without interaction,
  before doing anything.
- **No networking** (helper rule 6): the helper links no networking code and makes no
  connections. It logs with `Logger(subsystem: "com.afraidias.Relente", category: "helper")`:
  every request, every refusal with its reason, and the result. Fingerprints and serial numbers
  aren't written to the log.

### Permissions screen (new, "step 0")
Shown whenever the helper isn't installed and approved (Decision 3):
- **At launch**, instead of Installer: the first launch, after uninstalling it, or after the user
  turned it off in System Settings. When the helper is ready, the app starts on Installer.
- **While the app runs**, the app keeps reading the helper's status (every 2 s and when the app
  becomes active). If it stops being ready on Installer, USB Drive or Review (the user turned
  Relente off in System Settings, or removed it), the assistant crossfades back to Permissions,
  keeping the chosen installer and drive, and VoiceOver says "The system helper was turned
  off.". Once it's ready again, "Continue" goes to Installer with both still chosen.
- **Never during a creation or on Done:** a format that loses the helper fails with "The system
  helper didn't respond." (below); Done and Error stay as they are.

Layout: option **E** of the design canvas "Relente · Permissions", chosen by the owner so the
screen looks like the assistant's other screens (Decision 9). It replaces the three
Settings-style items `docs/product.md` described.
- **Header:** **"Set Up Relente"** and the subtitle "Relente needs a small system helper to erase
  drives. You only do this once.", as on every screen.
- **Hero:** the app icon (104 pt) in a halo, like the drive on Review, Creating and Done. Under it,
  one line saying where the helper stands, and the waiting indicator of the empty states while
  macOS waits for the user:

  | Status | Halo and badge | Line under the hero | Waiting indicator | Footer button |
  | --- | --- | --- | --- | --- |
  | Not installed | Blue (accent), no badge | "The system helper isn't installed." | — | **"Install Helper"** |
  | Waiting for approval (macOS needs the user to turn it on) | Blue, no badge | "Turn on Relente in System Settings › General › Login Items." | "Waiting for approval…" | **"Open Settings…"**, which opens Login Items |
  | Ready | Green, with a green check badge (as on Done) | "System helper ready." | — | **"Continue"** |
  | Failed (registering failed) | Red, with a red badge (as on Error) | "The system helper couldn't be installed." and a localized recovery hint below it, gray | — | **"Try Again"** |

  Technical errors from macOS are kept in the helper log and are never shown verbatim in the UI.
  The failure screen explains a safe next step in plain language.

  While installing or retrying, the footer button is disabled and shows an activity indicator with
  an appropriate progress label. This makes an immediate repeated failure visibly respond to the
  user's action.

  The status updates by itself: it's read again when the app becomes active and every 2 s while
  the screen is shown.
- **Callout** (the content width, 640 pt, styled like Review's warning but blue, since it only
  informs): a Touch ID symbol when available, otherwise `lock`; **"Each erase asks for your permission"** and matching copy explaining Touch ID or administrator password on every erase.
- **Footer:** no step indicator (it isn't one of the four steps); one primary button, the default
  action (Return), which is the next thing to do (table above).
- "Continue" goes to Installer with a crossfade (as a start). VoiceOver announces each status
  change ("System helper ready.").

### Erase and Create (changes specs 003, 004 and 006)
In Debug builds with real drives:
1. On Review, "Erase and Create" (still never the default action) first asks for authorization:
   macOS's authorization dialog, which offers Touch ID when available and otherwise asks for the administrator password. **If the user cancels it, nothing happens**: the
   assistant stays on Review with the checkbox still checked.
2. If the helper isn't ready (turned off in System Settings meanwhile), an alert says **"The
   System Helper Is Off"**, "Turn on Relente in System Settings › General › Login Items, then try
   again.", with "Open Settings…" (default) and "Cancel" (Esc). The assistant stays on Review.
3. Otherwise the assistant goes to Creating and the helper formats the drive. **Format** is real:
   it shows no percentage while `diskutil` works (as spec 004 allows for a phase), then completes.
   Copy, Make bootable and Verify are then simulated as today.
4. The simulation label reads **"SIMULATION · Only the format is real"** on Creating, Error and
   Done, since the drive really is erased.
5. "Cancel" and "Stop" during Format end `diskutil`; the drive is left unusable until it's erased
   again, which the Stop sheet already says.

With `-sampleData YES` (sample drives aren't real) and in UI tests, nothing changes: no helper, no
authorization dialog, everything simulated, and the label keeps "SIMULATION · Nothing is erased".
Release builds keep "Erase and Create" disabled with "Available in a later version." until roadmap
step 7.

**New failures** on the Error screen (spec 004's layout, reason and what to do as the subtitle):

| Reason | Title | What to do | "Try Again" goes to |
| --- | --- | --- | --- |
| The fingerprint doesn't match | "The drive changed after you confirmed it." | "Check it's the right drive and choose it again." | USB Drive, no drive selected (like a disconnection, spec 007 Decision 13) |
| The helper refuses the drive (rule 3) | "Relente can only erase USB drives and SD cards." | "Use a different drive." | USB Drive, no drive selected |
| `diskutil` fails | "The drive couldn't be erased." | "Try again, or use a different drive." | Review |
| The helper doesn't answer or is outdated | "The system helper didn't respond." | "Try again. If it keeps happening, quit and open Relente again." | Review |
| The helper rejects the authorization | Mapped to the existing "Something went wrong…" (unknown) | — | Review |

A drive unplugged during Format fails with the existing "The drive was disconnected.".

### Touch ID on "Erase and Create" (changes specs 005 and 006)
- Authorization Services is the actual authorization flow and may offer Touch ID; LocalAuthentication availability is a display hint only. Show `touchid` when Touch ID is available and `lock` for password fallback on Review and Permissions. The helper continues to verify fresh authorization for its custom right on every erase.

### Uninstalling the helper (helper rule 6)
- The app menu gets **"Uninstall System Helper…"** (after "About Relente", in its own section),
  disabled while a drive is being formatted or created.
- It shows an alert: **"Uninstall the System Helper?"**, "Relente can't create installers without
  it. You can install it again at any time.", with **"Uninstall"** and **"Cancel"**. Return and Esc
  answer "Cancel"; "Uninstall" is click only (it isn't destructive to data, but undoes a setup).
- Uninstalling calls `SMAppService.unregister()`. Then the assistant crossfades to Permissions,
  keeping the installer that was chosen. If it fails, an alert gives the reason with "OK".

### Sample data
- Previews, unit tests and the UI test use a sample helper service, never the real helper or the
  authorization dialog.
- With `-sampleData YES` the helper is ready, so Permissions is skipped. **`-sampleHelper
  notInstalled`** (Debug only) starts with it not installed; "Install" then moves through Waiting
  for approval to Ready after a moment, so the whole Permissions screen can be walked and tested.

## Changes to earlier features
- **Spec 002 (USB Drive screen):** the drive's artwork (`DriveArtwork`) is drawn in the opaque
  system gray (`systemGray`) instead of the see-through secondary color, so it's the same gray on
  every screen: before, the hero's halo showed through it, tinting it blue on Review and Creating,
  green on Done and red on Error (found by the owner while reviewing the badges; chosen on the
  canvas, row "La memoria, igual en todas las pantallas").
- **Spec 003 (Review screen):** "Erase and Create" asks for authorization first; cancelling the
  dialog stays on Review; the helper-off alert; the Touch ID indicator or password-fallback `lock`; the
  usage bar drops its repeated drive-name and capacity heading, and spacing between the hero,
  figures and bar increases.
- **Spec 004 (Creating screen + Error):** Format is real in Debug with real drives, with no
  percentage; four new failure reasons, two of which send "Try Again" to USB Drive. Error's red
  badge becomes the shared `StatusBadge`: an opaque circle with a white cross, inside a ring that
  sets it apart from the artwork (white in light mode, the window's background in dark mode). The
  system symbol had no ring and, over the see-through drive, looked see-through too; found by the
  owner while reviewing Permissions and chosen on the canvas (frame "Insignias").
- **Spec 005 (Done screen):** the `lock` symbol item it deferred is done here (on Review). The
  check on the installer's icon becomes the same `StatusBadge` (20 pt instead of 18, so the ring
  fits), so every check and cross in the app looks alike.
- **Spec 006 (Assistant navigation):** a Permissions screen before Installer, without a step
  number, entered at launch, after uninstalling, or when the helper stops being ready on
  Installer, USB Drive or Review (crossfading back, keeping the choices); once a creation fails,
  the Error screen draws the drive itself instead of handing it to the assistant, which draws
  shared artwork above the whole screen and so covered the cross's ring (found by the owner); so
  on "Try Again" the drive comes in with Review instead of flying to it; the simulation label gets a second text;
  `SimulatedCreationService` keeps the full simulation for sample data and the UI test.
- **Spec 007 (Real detection):** the rule that tells which disks are USB drives or SD cards moves
  to the shared code, unchanged, so the helper uses the same one; drives also carry their serial
  number, for the fingerprint.
- `docs/product.md`: Permissions screen (option E: header, the app icon as hero, a status line,
  the authorization callout and one footer button, instead of three Settings-style items; shown
  whenever the helper is missing), the label, the `lock` symbol, the menu item. SECURITY.md gains how to uninstall the
  helper. BUILDING.md: the helper target and how to approve it while developing.

## Acceptance criteria

**Security rules (each one tested)**
- [x] Rule 1: the XPC protocol has only `protocolVersion`, `format` and `cancel`; `diskutil` runs
  with a fixed path and its arguments as an array (the argument list is built by a tested
  function).
- [x] Rule 2: the code-signing requirement strings for the app and the helper include the
  identifier and the Team ID (tested); in a signed Debug build, the app connects to the helper,
  and a copy of the app signed differently is refused (checked by hand).
- [x] Rule 3: the identifier check accepts `disk4` and rejects `disk4s1`, `disk`, `../disk4`,
  `disk4 ` and an empty string; the drive check accepts a USB drive and an SD card (also a
  built-in slot) and rejects partitions, internal, fixed external and virtual disks, the boot
  disk and sizes outside 8 GB–2 TB; the fingerprint check fails when any part differs and when
  there's neither media UUID nor serial number (all tested, as pure functions on
  `DiskDescription` values).
- [x] Rule 5: a request whose authorization is missing or doesn't grant
  `com.afraidias.Relente.erase` is refused before any disk is read (tested with the checking
  behind a protocol); by hand, each erase asks again, and cancelling the dialog erases nothing.
- [x] Rule 6: the helper has no networking code; "Uninstall System Helper…" unregisters it (by
  hand: it disappears from Login Items and Permissions appears).

**Permissions**
- [x] With the helper missing, the app opens on Permissions; when ready, on Installer (tested on
  the assistant with the sample helper service).
- [x] Turning the helper off on Installer, USB Drive or Review goes back to Permissions within 2 s,
  keeping the installer and drive; "Continue" then returns to Installer with both chosen; on
  Creating and Done nothing changes (tested; and by hand in System Settings).
- [x] Each helper status shows its halo, badge, line and footer button (option E); "Open
  Settings…" opens Login Items; turning the helper on in System Settings updates the screen within
  2 s without clicking; and "Continue" appears only when Ready (tested with the sample service,
  and by hand).
- [x] Helper registration failures show a localized recovery hint and do not expose raw macOS
  codesigning or service error details; the diagnostic reason remains in the helper log.
- [x] Installing or retrying the helper shows a disabled progress button until registration
  resolves, including when macOS rejects the same signed plist immediately.
- [x] The UI test walks Permissions (`-sampleHelper notInstalled`) and then the whole flow.

**Erase and Create**
- [x] In a Debug build with a real USB drive, "Erase and Create" asks for Touch ID when available and otherwise the administrator password,
  the drive is erased as "MyVolume" (Mac OS Extended (Journaled), GPT), and the run continues simulated to Done
  with "SIMULATION · Only the format is real" (checked by hand).
- [x] A different physical USB drive with the same displayed volume name substituted after Review is not erased. The app returns to USB Drive with no selection and Continue disabled when the selected medium disappears; a stale request reaching the helper is rejected by its fingerprint check (unit tested). On 2026-10-26, this UI path was checked with the Toshiba and a Lexar both named `MyVolume`.
- [x] Each new failure reason shows its title and recovery, and "Try Again" goes where the table
  says (tested).
- [x] Review and Permissions show `touchid` when Touch ID is available and `lock` for password fallback; the erase remains protected by the helper-verified Authorization Services right.
- [x] Review does not repeat the drive name and capacity above the usage bar; its hero, figures
  and bar have visibly distinct spacing in Spanish and English, light and dark mode, and classic
  controls, without shrinking text or clipping the warning/footer.

**General**
- [x] Builds universal in Release with warnings as errors, the helper included; tests and lint
  pass, the new folders included.
- [x] New strings are in English and Spanish; Permissions has previews for each status, in light
  and dark, Liquid Glass and classic.
- [x] Works in light and dark mode, with VoiceOver (status changes announced) and with Reduce
  Motion.
- [x] Follows Apple's Human Interface Guidelines for macOS (onboarding asks for the permission in
  context and says why; alerts; the uninstall alert's buttons).

## Boundaries
- **Always:** the helper re-validates every request by itself; the fingerprint is compared right
  before `diskutil` runs; every erase asks for authorization; tests never talk to the real helper
  and never erase anything.
- **Ask first:** these changes, which this spec asks the owner to approve with it: adding the
  helper target and the shared folder to the Xcode project; adding the new folders to the lint
  command in CI and AGENTS.md; checking the helper's architectures in CI too.
- **Never:** erase with `-sampleData YES` or in a test; log fingerprints or serial numbers; let
  Return start an erase or an uninstall.

## Edge cases
- **The user cancels the authorization dialog:** stays on Review, nothing sent to the helper.
- **The helper is turned off in System Settings while on steps 1–3:** back to Permissions, keeping
  the choices (above). If it happens in the 2 s before the next check and the user clicks "Erase
  and Create" first, the alert on "Erase and Create" (above) catches it.
- **An outdated helper** (an older app's helper still running after an update): the app compares
  `protocolVersion`; if it differs, it reconnects once (launchd starts the new one); if it still
  differs, the "didn't respond" failure.
- **The format gives the drive a new identity:** erasing writes a new partition map, so the drive's
  media UUID (the id the app follows it by, spec 007) changes. While a creation runs, and on Done,
  the assistant follows the drive by its BSD name (`disk4`), which stays the same while it's
  connected, so the run isn't taken for a disconnection and "Eject" still finds it. During Format
  the drive may also vanish for a moment while `diskutil` repartitions it; a real disconnection
  then comes from the helper ("The drive was disconnected.").
- **The drive is unplugged and another one plugged in with the same BSD name:** the fingerprint
  differs, refused.
- **The same physical drive is reformatted between Review and Erase:** this does not substitute the physical medium. On 2026-10-26 the helper accepted the same Toshiba and formatted it again, so this is not a valid test of rejecting a replacement drive. A different physical drive with a different fingerprint is required for the manual substitution test.
- **Two Relente windows or a second erase at once:** the helper handles one format at a time and
  refuses a second request while one runs (logged); the UI already allows only one.
- **The app is quit during Format:** the helper finishes or stops `diskutil` on its own when the
  connection drops (ends it, as with Cancel).
- **Registering the helper from a build outside `/Applications`:** to verify while planning;
  BUILDING.md will say where to run it from if macOS requires it.
- **Touch ID in the dialog:** the owner wants Touch ID when available, otherwise password. The
  custom Authorization Services dialog was observed to offer password in an earlier run and Touch ID
  in a later run on 2026-10-26. The UI uses LocalAuthentication only to choose its indicator; the
  system dialog performs authorization and the helper verifies its custom right on every erase.
  Issue #33 tracks checking this behavior across supported Macs and macOS versions.

## Decisions
1. **The format is real in this step; the rest stays simulated.** Chosen by the owner: it's the
   only way to check rules 3 and 5 end to end, with a real erase right after the fingerprint
   check. The label says so, since "Nothing is erased" would be false.
2. **Permissions is about the helper and the authorization, without Full Disk Access or
   "Signature verified".** Chosen by the owner. The helper runs as root and writes to the disk directly, and the app never reads
   protected folders, so Full Disk Access isn't needed (to confirm in roadmap step 7 with
   `createinstallmedia`). The signature checks aren't something the user grants: they happen
   between the app and the helper, and are covered by rule 2.
3. **Permissions appears whenever the helper is missing, also while the app runs.** Chosen by the
   owner. The first version of this spec only showed it at launch, so turning the helper off with
   the app open said nothing until "Erase and Create"; the owner found it at Checkpoint B and asked
   for it to be noticed at once (seen on the canvas "Relente · Permissions", row "Si desactivas el
   ayudante con la app abierta"). The assistant keeps the chosen installer and drive, as it does
   when a drive is unplugged on Review (spec 007), and never interrupts a creation.
4. **Uninstall from the app menu.** Chosen by the owner: no Settings window is needed for one
   action.
5. **The helper accepts drives of 8 GB to 2 TB.** The smallest supported installer (Big Sur) needs
   more than 8 GB, and USB drives and SD cards (SDXC) go up to 2 TB; anything outside is refused
   even if the app asked for it. The owner can change the limits.
6. **A drive with neither media UUID nor serial number is refused.** Its size alone could match
   another drive. Such drives are rare (most report a serial number); it's the safe side, as in
   spec 007 Decision 7.
7. **The helper creates the authorization right itself**, since it runs as root and doesn't need
   to ask the user for it; the app never writes to the authorization database.
8. **Format the whole drive first, as Mac OS Extended (Journaled) named "MyVolume", like Apple's
   guide.** Chosen by the owner after comparing with Apple's guide (support.apple.com/101578),
   where `createinstallmedia` alone erases a volume named "MyVolume" as Mac OS Extended
   (Journaled). The guide assumes the drive already has a mounted Mac volume; formatting the whole
   disk first (GPT, one volume) makes every drive start the same, including ones with no mounted
   volume (Linux formats, unformatted) or with an MBR partition map. For the user it's still one
   click and one authorization. The name is Apple's; `createinstallmedia` renames the drive in
   roadmap step 7, and until then it's what the Finder shows after a simulated run (Done still
   shows the name the real creation will leave, as built in spec 005).

9. **Permissions looks like the other screens (option E of the canvas "Relente · Permissions").**
   Chosen by the owner after a first version with Settings-style rows (option A) and three other
   layouts (compact rows, two columns, numbered steps) that didn't match the rest of the app. It
   uses the parts every screen has: the header, a hero with a halo and a badge, the waiting
   indicator of the empty states, a callout at the content width, and one primary button in the
   footer that is always the next thing to do. The callout is blue rather than orange because it
   only informs. The app icon is the hero because the helper has no artwork of its own.

10. **The erase right delegates to `authenticate-admin-nonshared`.** Found at Checkpoint C: a rule
   of its own with no timeout made the credential expire the moment it was granted, so the helper's
   own check failed (-60007) and nothing was erased; macOS's standard rule for this case keeps it
   30 s and never shares it. Each erase still asks, because each one uses a new authorization.

11. **Give Review more breathing room.** Chosen by the owner after reviewing a mockup on
   2026-10-26: remove the drive-name and capacity heading above the usage bar because the hero
   already identifies the same drive. Set 36 pt after the hero, 16 pt between stats and bar, and
   20 pt between the bar and warning so the figures and bar have distinct spacing and the warning
   stays in place. Preserve the footer, window size and text sizes.
12. **Show the available authorization method.** Authorization Services showed a password dialog
   in an earlier run and Touch ID in a later run on 2026-10-26. The indicator reflects Touch ID
   availability, with password as fallback; the system dialog and helper's custom-right check remain
   the security boundary.
13. **Test physical identity with a different medium.** Reformatting the same Toshiba while it
   stays connected does not substitute the physical device: the helper accepted it and formatted it
   again, and volume verification passed. On 2026-10-26 the owner connected a Lexar; after both
   volumes were temporarily named `MyVolume`, ejecting the selected Toshiba while on Review caused
   the app to return to USB Drive, clear selection and disable Continue. This no-erase UI path is
   verified; the helper fingerprint mismatch path remains covered by unit tests.

## Open questions
None.

## Open items
- **Roadmap step 8:** verify Authorization Services Touch ID and password fallback behavior across
  supported Macs and macOS versions during signed Release validation, while preserving fresh
  administrator authorization verified by the helper. The current Mac showed both methods. Apple
  documents that Authorization Services uses the Security Agent and can adopt authentication
  methods such as Touch ID without an app-side authorization bridge
  ([Authorization Services](https://developer.apple.com/documentation/security/authorization-services)).
  The investigation and current implementation are recorded in
  [closed issue #33](https://github.com/afraidias/Relente/issues/33).
- **Roadmap step 7:** add running `createinstallmedia` to the helper (rule 1) and check the
  installer's and `createinstallmedia`'s Apple signature right before running it (rule 4); mount
  `.dmg` installers read-only from the helper; confirm Full Disk Access isn't needed (Decision 2);
  replace the simulated phases and the simulation label; enable "Erase and Create" in Release.
- **Roadmap step 8:** check that the helper registers and connects in the signed and notarized
  Release build (Developer ID), and that rule 2 refuses an app signed by another team in that
  build.
