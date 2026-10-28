# Permission and creation flow investigation

**Status:** Research in progress · **Baseline:** main at PR #42 (`a1f38ba`)

## Goal

Make Relente approachable without requesting access earlier or more broadly than needed, while
keeping the confirmed-drive, administrator-authorization and Apple-signature protections. This
is research, not an approved change to the finished specs or permission to erase a drive.

## Evidence

- Apple documents `softwareupdate` for listing and downloading compatible full installers, and
  `createinstallmedia` with `sudo` for creating media. The latter may prompt Terminal for access
  to removable volumes: [download](https://support.apple.com/en-us/102662),
  [create](https://support.apple.com/en-us/101578).
- Apple recommends requesting access when the relevant feature needs it:
  [Privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy/).
- Apple supports privileged launch daemons with Service Management; a daemon registration is
  subject to administrator approval. The older generic privilege-execution API is deprecated:
  [Service Management](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos),
  [AuthorizationExecuteWithPrivileges](https://developer.apple.com/documentation/security/authorizationexecutewithprivileges).
- In merged spec 010, a helper-side removable-volume write failed with error 513 and TCC reported
  unavailable authorization for the root daemon. An app-side scoped probe succeeded but did not
  confer access on the helper. With Full Disk Access enabled, the helper preflight and a real
  creation succeeded on the validation Mac. Other macOS versions remain unverified.
- The merged `Assistant` starts on Permissions when the helper is not ready and redirects there
  if the helper becomes unavailable on Installer, USB Drive or Review. This conflicts with spec
  010's instruction not to block installer browsing. Selection is held in the app, so there is a
  plausible route to delaying setup, but it has not been implemented or tested.
- The helper is launch-on-demand; `HelperListener` exits after 60 seconds without connections.
  It remains registered with macOS, which is different from continuously running.
- An [Apple Developer Forums case](https://developer.apple.com/forums/thread/802650) describes
  scoped access after an app-side raw-device access attempt and a secondary process inheriting
  access. That case is not the same as Relente's daemon and `createinstallmedia`; it is a lead,
  not proof. Apple's [removable-volumes documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremovablevolumesusagedescription)
  says a newly created file may be accessible without prompting, so a successful create/delete
  probe alone does not establish general access or the behavior of another process.

## Candidate flow

1. Start on Installer, regardless of helper registration; allow local choice and eventual Apple
   downloads. Continue to USB Drive and Review without elevated access.
2. At Review, if setup is needed, explain it in context and offer the relevant system action.
   Resume Review after returning from Settings. Cancellation or refusal leaves browsing usable.
3. Before an erase, revalidate the chosen installer and disk, require explicit confirmation and
   fresh administrator authorization, and check actual write access from the relevant process.
   A changed or removed disk is selected again; never resume an erase automatically after setup.

This changes specs 008 and 010 and requires a new approved spec before implementation. It does
not itself remove any operating-system permission, and must handle a helper disabled mid-flow.

## Investigation matrix

| Candidate | Question | Status |
| --- | --- | --- |
| Delay helper setup until Review | Can selection and recovery work without the daemon ready? | Supported by code structure; needs tests and design review. |
| Existing daemon with removable-volume permission | Can the process that executes `createinstallmedia` access the target without Full Disk Access? | Not proven; the prior app-side probe did not transfer access. |
| User-session execution plus narrowly privileged operation | Is there a public, supported route preserving user-session access, per-erase authorization and independent disk validation? | No verified implementation identified. A user LaunchAgent is not itself root. |
| Terminal-like direct execution | Does Apple document a supported app privilege mechanism with equivalent protections and less setup? | No current supported replacement established; avoid deprecated generic execution. |

## Non-destructive validation protocol

Use a clean test account or VM snapshot and a dedicated disposable removable volume. Record macOS
version, architecture, app signing identity, helper state, Terminal permissions and exact TCC
settings. Do not reset all TCC permissions or alter unrelated app permissions. Do not erase the
volume or invoke `createinstallmedia` during these checks.

1. Establish the existing baseline with Full Disk Access off: independently observe app, helper
   and a fixed harmless child process accessing a known test file on the selected volume. Record
   each result, any prompt and TCC attribution. The file contains no personal data.
2. Test the system's scoped Removable Volumes consent in the app, then repeat each probe; do not
   infer helper or child access from the app's result. Verify denial and recovery as well as grant.
3. Investigate the forum's raw-device approach only after confirming a non-writing read/open can
   exercise the relevant policy; do not open a raw disk for writing or claim that a file probe
   proves what `createinstallmedia` can do. If the safe probe cannot establish this, record it as
   inconclusive rather than escalating it into a write.
4. Test navigation with sample services: helper absent, denied, disabled after selection, return
   from Settings, installer disappearance and USB disconnection. A stale confirmation must never
   cause an automatic erase.
5. If a supported candidate passes the non-destructive checks, define a separate, explicitly
   confirmed real-drive validation for the complete Apple command, with Full Disk Access off,
   and repeat as practical on supported macOS and Intel/Apple silicon. A harmless probe alone
   cannot establish that the full command succeeds.

No experiments have been run yet. No permission reset, helper registration or real-drive erase
is authorized by this research document itself.

## Separate preparation from erase

The owner agreed to investigate separating preparation from the destructive action. On Review,
preparation should check helper readiness and any safely checkable access, explain missing setup,
then return to Review with valid selections intact. It must never invoke `createinstallmedia` or
begin an erase. A separate explicit Erase and Create action then requires the existing fresh
administrator authorization and independently revalidates the disk fingerprint and installer
immediately before the operation. A successful earlier probe is not a lasting guarantee.

The current typed helper write probe itself requires an authorization. Investigate whether a
strictly limited non-destructive probe can safely be offered before erase without introducing a
second administrator prompt, or whether an authorization must be obtained at that point. Do not
weaken the authorization on destructive operations or assume a short-lived authorization remains
valid after time in Settings. Compare actual prompts and recovery on the supported systems.

A diagnostic harness for this investigation should use its own service identity, a narrowly typed
probe and appropriate code signing; it must not replace the registered production helper or expose
a command runner. An app-side success is not proof of helper or `createinstallmedia` access.
Preparing the harness and obtaining results remains outstanding; no probe has been run yet.
