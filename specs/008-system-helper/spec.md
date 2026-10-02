# 008 · System helper, XPC and security checks

**Status:** Approved · **Roadmap step:** 6 · **Branch:** `feature/008-system-helper`

## Objective
Give Relente the only part of it that can erase a disk: a small helper that runs as root, which
the app installs with `SMAppService` and talks to over XPC, following the six helper security
rules of AGENTS.md and SECURITY.md. The user installs it once, on a new **Permissions** screen
that only appears while the helper is missing, and can uninstall it from the app's menu.

At the end of this step "Erase and Create" really asks for Touch ID or the administrator
password, and the helper re-validates the drive and **really formats it**; copying the installer,
making it bootable and verifying stay simulated in Debug builds until roadmap step 7, which adds
`createinstallmedia` to the helper. Release builds keep "Erase and Create" disabled until then.

This feature also does the work earlier specs deferred to roadmap step 6: the helper re-validates
the drive (spec 007) and the Permissions screen (spec 007, `docs/product.md`), and "Erase and
Create" shows a `lock` instead of `touchid` on Macs without Touch ID (specs 005 and 006).

Chosen by the owner before writing the spec: real format with the rest simulated; Permissions
with two items (helper and authorization), without Full Disk Access; Permissions shown whenever
the helper is missing; uninstalling from the app menu.

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
  `com.afraidias.Relente.erase`, that asks an administrator to authenticate every time (not
  shared, no timeout). The helper creates it in the authorization database the first time it
  runs. The app asks for it (macOS shows its standard dialog, with Touch ID on Macs that have it)
  and sends it to the helper with the request; the helper checks it again, without interaction,
  before doing anything.
- **No networking** (helper rule 6): the helper links no networking code and makes no
  connections. It logs with `Logger(subsystem: "com.afraidias.Relente", category: "helper")`:
  every request, every refusal with its reason, and the result. Fingerprints and serial numbers
  aren't written to the log.

### Permissions screen (new, "step 0")
Shown at launch instead of Installer when the helper isn't installed and approved: first launch,
after uninstalling it, or after the user turns it off in System Settings. When the helper is
ready, the app starts on Installer and this screen is never shown.

Layout, as `docs/product.md` describes it (its contents change; see "Changes to earlier
features"):
- The app icon, then the header: **"Set Up Relente"** and the subtitle "Relente needs a small
  system helper to erase drives. You only do this once.".
- Two items in a column, styled like System Settings rows (a colored rounded-square icon, a title,
  a line of explanation, and a status badge or action at the trailing edge):

  | Item | Icon | Explanation | Trailing edge |
  | --- | --- | --- | --- |
  | **System Helper** | `lock.shield`, blue | "Erases and prepares drives for Relente. It runs only while Relente uses it." | The helper's status (below) |
  | **Administrator Authorization** | `touchid` (`lock` on Macs without Touch ID), red | "Each erase asks for Touch ID or your password." (or "…for your password." without Touch ID) | Nothing: it's asked for at each erase |

- **System Helper's status**, which updates by itself (checked when the app becomes active, and
  every 2 s while the screen is shown):

  | Status | Trailing edge |
  | --- | --- |
  | Not installed | "Install" button |
  | Waiting for approval (macOS needs the user to turn it on) | Orange "Needs approval" badge and "Open Settings…" button, which opens System Settings › General › Login Items |
  | Ready | Green "Ready" badge |
  | Failed (registering failed) | Red "Couldn't install" badge, the reason as the help tag, and "Try Again" |

- Below the items, a gray reassurance line: "Relente never erases a drive without asking you
  first."
- **Footer:** no step indicator (it isn't one of the four steps); "Continue", primary, disabled
  until System Helper is Ready, and the default action once it is. Before that, the default
  action (Return) is the item's own button ("Install", "Open Settings…" or "Try Again").
- "Continue" goes to Installer with a crossfade (as a start). VoiceOver announces each status
  change of System Helper ("System helper ready.").

### Erase and Create (changes specs 003, 004 and 006)
In Debug builds with real drives:
1. On Review, "Erase and Create" (still never the default action) first asks for authorization:
   macOS's dialog, with Touch ID or the password. **If the user cancels it, nothing happens**: the
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

### Touch ID or password on "Erase and Create" (changes specs 005 and 006)
- "Erase and Create" shows `touchid` on Macs that can use Touch ID (built-in or a paired Magic
  Keyboard with Touch ID), and `lock` otherwise. It's checked each time Review is shown, so a
  keyboard connected meanwhile counts.
- The same rule chooses Permissions' Administrator Authorization icon and text.

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
- **Spec 003 (Review screen):** "Erase and Create" asks for authorization first; cancelling the
  dialog stays on Review; the helper-off alert; `lock` instead of `touchid` without Touch ID.
- **Spec 004 (Creating screen + Error):** Format is real in Debug with real drives, with no
  percentage; four new failure reasons, two of which send "Try Again" to USB Drive.
- **Spec 005 (Done screen):** the `lock` symbol item it deferred is done here (on Review).
- **Spec 006 (Assistant navigation):** a Permissions screen before Installer, without a step
  number, entered at launch or after uninstalling; the simulation label gets a second text;
  `SimulatedCreationService` keeps the full simulation for sample data and the UI test.
- **Spec 007 (Real detection):** the rule that tells which disks are USB drives or SD cards moves
  to the shared code, unchanged, so the helper uses the same one; drives also carry their serial
  number, for the fingerprint.
- `docs/product.md`: Permissions screen (two items instead of three, shown whenever the helper is
  missing), the label, the `lock` symbol, the menu item. SECURITY.md gains how to uninstall the
  helper. BUILDING.md: the helper target and how to approve it while developing.

## Acceptance criteria

**Security rules (each one tested)**
- [ ] Rule 1: the XPC protocol has only `protocolVersion`, `format` and `cancel`; `diskutil` runs
  with a fixed path and its arguments as an array (the argument list is built by a tested
  function).
- [ ] Rule 2: the code-signing requirement strings for the app and the helper include the
  identifier and the Team ID (tested); in a signed Debug build, the app connects to the helper,
  and a copy of the app signed differently is refused (checked by hand).
- [ ] Rule 3: the identifier check accepts `disk4` and rejects `disk4s1`, `disk`, `../disk4`,
  `disk4 ` and an empty string; the drive check accepts a USB drive and an SD card (also a
  built-in slot) and rejects partitions, internal, fixed external and virtual disks, the boot
  disk and sizes outside 8 GB–2 TB; the fingerprint check fails when any part differs and when
  there's neither media UUID nor serial number (all tested, as pure functions on
  `DiskDescription` values).
- [ ] Rule 5: a request whose authorization is missing or doesn't grant
  `com.afraidias.Relente.erase` is refused before any disk is read (tested with the checking
  behind a protocol); by hand, each erase asks again, and cancelling the dialog erases nothing.
- [ ] Rule 6: the helper has no networking code; "Uninstall System Helper…" unregisters it (by
  hand: it disappears from Login Items and Permissions appears).

**Permissions**
- [ ] With the helper missing, the app opens on Permissions; when ready, on Installer (tested on
  the assistant with the sample helper service).
- [ ] Each System Helper status shows its badge and button; "Open Settings…" opens Login Items;
  turning the helper on in System Settings updates the screen within 2 s without clicking; and
  "Continue" is enabled only when Ready (tested with the sample service, and by hand).
- [ ] The UI test walks Permissions (`-sampleHelper notInstalled`) and then the whole flow.

**Erase and Create**
- [ ] In a Debug build with a real USB drive, "Erase and Create" asks for Touch ID or the password,
  the drive is erased as "MyVolume" (Mac OS Extended (Journaled), GPT), and the run continues simulated to Done
  with "SIMULATION · Only the format is real" (checked by hand).
- [ ] A drive swapped for another one with the same name between Review and the erase is refused
  with "The drive changed…" and nothing is erased (fingerprint test, and by hand by reformatting
  the drive between Review and Erase if feasible).
- [ ] Each new failure reason shows its title and recovery, and "Try Again" goes where the table
  says (tested).
- [ ] `touchid` or `lock` is chosen from whether the Mac can use Touch ID (the choice is a tested
  function of the capability).

**General**
- [ ] Builds universal in Release with warnings as errors, the helper included; tests and lint
  pass, the new folders included.
- [ ] New strings are in English and Spanish; Permissions has previews for each status, in light
  and dark, Liquid Glass and classic.
- [ ] Works in light and dark mode, with VoiceOver (status changes announced) and with Reduce
  Motion.
- [ ] Follows Apple's Human Interface Guidelines for macOS (onboarding asks for the permission in
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
- **The helper is turned off in System Settings while on steps 1–3:** the alert on "Erase and
  Create" (above); Permissions is only shown at launch or after uninstalling, so the user doesn't
  lose their place.
- **An outdated helper** (an older app's helper still running after an update): the app compares
  `protocolVersion`; if it differs, it reconnects once (launchd starts the new one); if it still
  differs, the "didn't respond" failure.
- **The drive is unplugged and another one plugged in with the same BSD name:** the fingerprint
  differs, refused.
- **A drive reformatted in Disk Utility between Review and the erase:** its media UUID changes,
  refused as "changed"; the user picks it again.
- **Two Relente windows or a second erase at once:** the helper handles one format at a time and
  refuses a second request while one runs (logged); the UI already allows only one.
- **The app is quit during Format:** the helper finishes or stops `diskutil` on its own when the
  connection drops (ends it, as with Cancel).
- **Registering the helper from a build outside `/Applications`:** to verify while planning;
  BUILDING.md will say where to run it from if macOS requires it.
- **Touch ID in the dialog:** macOS decides whether its dialog offers Touch ID for this right; if
  it turns out to ask only for the password, the button and Permissions show `lock` everywhere and
  the texts say "password" (checked at the first checkpoint).

## Decisions
1. **The format is real in this step; the rest stays simulated.** Chosen by the owner: it's the
   only way to check rules 3 and 5 end to end, with a real erase right after the fingerprint
   check. The label says so, since "Nothing is erased" would be false.
2. **Permissions has two items, without Full Disk Access or "Signature verified".** Chosen by the
   owner. The helper runs as root and writes to the disk directly, and the app never reads
   protected folders, so Full Disk Access isn't needed (to confirm in roadmap step 7 with
   `createinstallmedia`). The signature checks aren't something the user grants: they happen
   between the app and the helper, and are covered by rule 2.
3. **Permissions appears whenever the helper is missing, at launch.** Chosen by the owner. During
   the flow, a missing helper is an alert on "Erase and Create" instead, so the user doesn't lose
   the installer and drive they chose.
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

## Open questions
None.

## Open items
- **Roadmap step 7:** add running `createinstallmedia` to the helper (rule 1) and check the
  installer's and `createinstallmedia`'s Apple signature right before running it (rule 4); mount
  `.dmg` installers read-only from the helper; confirm Full Disk Access isn't needed (Decision 2);
  replace the simulated phases and the simulation label; enable "Erase and Create" in Release.
- **Roadmap step 8:** check that the helper registers and connects in the signed and notarized
  Release build (Developer ID), and that rule 2 refuses an app signed by another team in that
  build.
