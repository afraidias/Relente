# Isolated Ventura preparation experiment — proposal

Revision: 1 · State: Draft · Execution: Not started

This is a research protocol for the already downloaded, Apple-verified Ventura 13.7.8 package.
It is not the feature implementation plan or an accepted production preparation design.

## Question and boundaries

Can Apple's expansion tool and explicit, unprivileged assembly produce a complete installer
whose app and createinstallmedia satisfy Apple signature requirements and whose OS identity is
13.7.8 / 22H730, without executing installation scripts or writing to /Applications?
Do not launch the app, createinstallmedia or startosinstall. Do not install the package. Do not
change ownership to root or invoke the privileged helper. No physical disk operations.

## Storage and containment

Use a newly created 32 GiB sparse disk image in the existing owned research directory, formatted
with a separate filesystem. Mount only that research image at an explicit owned mountpoint with
Finder browsing disabled. Record its image path, mountpoint and returned device identity. Never
choose a device by enumeration or detach an unidentified disk. Apple's installed hdiutil(1)
documents sparse-image growth up to the size specified at creation; actual allocation includes
filesystem/image overhead, so this is an approximate backing-storage bound, not a byte-perfect
host quota. Keep at least 40 GiB host free before starting. Do not resize on an out-of-space error.

The original 12.21 GB package stays outside the image. Proposed image contents: one full expansion
(about 12.2 GB plus nested payload), one assembled app with an independent package-as-SharedSupport
copy (about 12.3 GB), plus metadata and margin. Do not depend on a clone/hard-link saving space.
The declared 39,041 KiB payload size is an estimate to check, not a trusted decompression limit.
Record actual usage. Stop if expansion exceeds the image capacity or approaches the host reserve.

A separate filesystem limits destination storage; it does not sandbox an extractor or prevent
path traversal. Inspect known top-level XAR paths first and use only the verified fixed sample
and Apple's tool. Do not claim this proves safe handling of arbitrary hostile archives. Production
path containment, nested symlink handling and malicious-input tests remain design requirements.
Set the extractor's temporary directory inside the research image where supported; this does not
prove that a tool has no other temporary writes. Record observed behavior and unresolved limits.

## Ordered experiment

1. Confirm the original package still has exact length and recorded SHA-256; re-evaluate Apple
   package trust in a functioning system trust context. Any failure stops the experiment.
2. Create and attach the bounded research image; record capacity and identity before writes.
3. Run installed pkgutil --expand-full to a new, nonexistent destination within the image, as the
   ordinary user. Apply a 10-minute research timeout. Capture the owned PID and terminal exit,
   not merely the shell/task cancellation request. Do not execute extracted scripts.
4. Inspect output without following unreviewed symlinks. Record app location, nested files,
   executable permissions, symlink targets and actual expanded sizes. Unexpected paths or
   missing contents stop assembly; do not repair by running package scripts or requesting root.
5. Create a separate app candidate within the same bounded image using metadata-preserving Apple
   file-copy tools. Based on the observed Ventura script, place an independent copy of the entire
   verified package at Contents/SharedSupport/SharedSupport.dmg. Do not substitute the inner XAR
   entry, mutate the source package, install a system app or reproduce root ownership operations.
   Preserve executable bits and symlinks; reject links escaping the reviewed app layout.
6. Verify the assembled app and its createinstallmedia using strict code-signature validation
   and an Apple anchor requirement, without executing either. Record exact commands/exit codes.
   A successful signature check alone is not proof of complete support assets or OS identity.
7. If necessary to identify OS version/build, attach only the candidate support image read-only
   and nobrowse at a distinct owned mountpoint; inspect fixed metadata files as data. Record the
   metadata source and distinguish OS version from package/app UI version. Detach by the device
   returned for that attachment, after readers terminate. No boot or installation test.
8. Compare observed OS identity with 13.7.8 / 22H730. Missing or conflicting identity means failure,
   not fallback to the catalog claim. Record success only for checks actually performed.
9. After all owned processes and readers terminate, detach only the research image. Retain its
   file and original package for review; deletion is a separate explicit cleanup action. Never
   delete files on an attachment that failed to detach or an uncertain mountpoint.

## Cancellation and recovery research

If cancellation or timeout occurs, signal only the owned extractor, await its terminal process
result and confirm no owned subprocess remains before detaching. A signalling error or uncertain
process state means incomplete cancellation; keep the artifacts isolated and report the state.
Do not use force detach, kill update services or clean shared caches. If detach fails, record the
actual mountpoint/device and leave it for recovery. Neither a detached image nor a dismissed UI
means an app is complete. This protocol does not yet test URLSession cancellation or app relaunch.

## Interpretation

Passing expansion, assembly, signatures and exact identity makes this sample a candidate for a
later accepted implementation design. It does not prove createinstallmedia runtime usability,
helper integration, other releases, release readiness or protection against arbitrary archives.
Failure returns to design review; never weaken signature requirements or bypass signing. The
next owner review should consider the results and unresolved containment/identity risks before
accepting the feature design. No execution of this protocol is recorded or implied here.


## Execution result — 2026-11-02

Owner replied "okey" to the concrete research proposal; executed this protocol as research,
not feature implementation. Original SHA-256 matched and pkgutil again reported signed Apple
Software outside the sandbox. Created a 32 GiB APFS sparsebundle and attached it nobrowse with
owners enabled. Returned identities: disk6 (image), disk7s1 (mounted APFS volume). pkgutil
--expand-full exited 0 within the 600-second bound, without running package scripts. All
extracted app symlinks resolved inside the app; createinstallmedia mode was 0755. Used ditto
to create a separate candidate and copy the original package to its SharedSupport.dmg path.
Image usage reached about 23 GiB, with 8.9 GiB remaining.

Initial codesign invocations omitted the '=' literal prefix on -R and failed to parse the
requirement; corrected syntax was -R '=anchor apple'. createinstallmedia passed --verify
--strict with the explicit Apple requirement. The candidate app failed --verify --deep --strict
with 'resource envelope is obsolete (custom omit rules)'. The untouched expanded app gave the
same failure under the same check, locating this issue in the source app's signing structure
rather than the SharedSupport composition step. No weaker check was substituted as success.
Stopped before support-image mount or exact OS identity verification. No installer executable
or script was run; no code, helper, Xcode or CI change. The research image was normally detached
via its returned disk6 identity; hdiutil confirmed ejection. Both the original package and
about 23 GiB of sparsebundle backing storage remain in the research directory for review.

Outcome: expansion and sample composition were possible, but the proposed strict full-app
validation criterion failed. This is not a validated complete installer. Cancellation was not
triggered in this run. Before continuing, investigate official signing policy and comparable
acquisition tools, without weakening project security requirements or assuming this old package
represents newer releases.


## Identity follow-up — 2026-11-03

After acceptance of the retained-package/private-helper direction, mounted the research image
read-only/nobrowse (returned disk6/disk7s1), then the candidate's complete-package SharedSupport
image read-only/nobrowse at a separate owned mountpoint (returned disk8/disk8s2). Read fixed
com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml as plist data.
All 74 Assets contain OSVersion=13.7.8 and Build=22H730; zero missing values and one unique pair,
matching catalog and current-Mac list. File size 1,000,633 bytes; SHA-256
34fa69bd5426204267bda17d861f7eca7b0184337473a4e7f1fe78709407aebb. InstallInfo.plist is empty in
this support image and cannot supply identity. No installer executable or script was run.
Normally detached disk8 then disk6; both ejections succeeded. This confirms observed sample
identity, not a stable cross-release metadata contract or complete helper trust validation.
