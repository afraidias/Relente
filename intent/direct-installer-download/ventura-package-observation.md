# Ventura package inspection — 2026-11-02

Research only. Owner authorized the smaller Ventura download, signature verification and package
structure inspection. No app implementation, installer execution, package-script execution, system
installation, /Applications write, disk-image mount or real-device operation was performed.

## Transfer and identity

- Product: `093-22004`; catalog/Distribution and current-Mac list identify Ventura 13.7.8 / 22H730.
- [Apple package URL](https://swcdn.apple.com/content/downloads/09/46/093-22004-A_QNZEDC334I/phigx2zvoggml6sh79my4y51fnvgy8hix4/InstallAssistant.pkg).
- curl exited 0: HTTP 200, 12,205,110,942 bytes, 1,400.206363 seconds (about 23 minutes 20 seconds).
- Exact byte count matches catalog and Content-Length. Initial and final URLs match; no redirects
  were followed. This establishes only this delivery sample's behavior.
- SHA-256: `5a5a197dfe87574119bfcdd123db567613999acd5a9d304c936280a31cb0e7c2`.
- Research directory: `/private/tmp/relente-ventura-research.BCNVcZ`. Download remains named
  `InstallAssistant.pkg.partial`; terminal transfer and signature results, not this filename,
  establish its research status. It has not been published as a selectable installer.

## Signature result and environment limitation

`pkgutil --check-signature` first exited 1 with invalid-signature status inside the sandbox.
The same command on the same bytes outside the sandbox exited 0 and reported signed Apple
Software. Observed chain: Software Update, Apple Software Update Certification Authority,
Apple Root CA. Certificate expirations shown were 2029-04-14, 2031-10-15 and 2035-02-09.
This difference demonstrates that the restricted execution context cannot be used as a definitive
package-trust result here. No trust policy was disabled or changed. A production verifier must
fail closed when trust evaluation is unavailable and distinguish inability to evaluate from a
proven bad signature. Human-readable certificate names alone are not an accepted production
signer policy; a reviewed cryptographic Apple identity check remains needed.

## Archive structure and preparation implication

`xar -tf` lists five top-level entries: SharedSupport.dmg, PackageInfo, Scripts, Payload and Bom.
After successful signature evaluation, only PackageInfo, Scripts and Payload were extracted to
an owned inspection subdirectory. Scripts were listed and streamed to stdout as text, never run.
The initial header had also been parsed as untrusted data while downloading; it was not used to
execute or publish anything.

Observed XAR entry uncompressed sizes: SharedSupport.dmg 12,194,123,287 bytes; Payload 10,927,736
bytes; Scripts 644 bytes; PackageInfo 923 bytes; Bom 275,809 bytes. These are XAR entry sizes,
not an upper bound on expanding the nested Payload.

PackageInfo declares root authorization, identifier com.apple.pkg.InstallAssistant.macOSVentura,
package version 22.7.730 and a payload of 1,010 files / 39,041 KiB. The installer bundle metadata
there declares CFBundleShortVersionString 18.7.62. Neither package version nor installer UI bundle
version is the requested macOS version 13.7.8. Do not use either as the OS identity without further
verified metadata. A post-install dispatcher invokes executable actions from its action folder.
The inspected action creates the app's Contents/SharedSupport directory and hard-links the entire
package into it as SharedSupport.dmg on the same filesystem, or copies the package across
filesystems. It also changes permissions, ownership and a file flag. This is an observation of
this signed package, not authorization to run or reproduce those privileged operations.

Consequently, expanding Payload alone is insufficient. Copying the internal XAR SharedSupport.dmg
entry is not what the inspected script does. `hdiutil imageinfo` outside the sandbox recognizes
the complete package itself as a read-only UDIF image (UDRO), consistent with this dual-container
layout. It reported a 12,938,137,600-byte logical image. No image was mounted. The command failed
inside the sandbox and emitted a deprecation warning on this host recommending diskutil image
info; this is a tooling limitation, not a preparation result.

The Payload begins with pbzx bytes; the installed tar command cannot list it (unrecognized
archive format). No third-party decompressor was installed and no custom decoder was written.
`pkgutil --expand-full` remains a candidate official tool, but has not been run and would not by
itself establish the required final SharedSupport composition or code-signature validity.

## Outcome and next boundary

The authorized download/signature/structure investigation is complete. It validates one genuine
Apple package and reveals a concrete composition dependency. It does not establish a usable
installer app, exact OS identity from the completed app, cancellation of preparation, extraction
containment or support for other package generations. No URLSession runtime behavior was tested
by this curl transfer.

Next proposed experiment: contain expansion in a separately bounded working volume/directory,
use an official expansion tool without executing scripts, inspect output paths and metadata,
then determine whether assembling the observed SharedSupport composition without privileged
side effects preserves Apple's app and createinstallmedia signatures. Define storage bounds and
cancellation/cleanup ownership before expanding. Treat this as research, not permission to begin
feature code. Current provisional budget can be reduced for this candidate only after accounting
for package retention, package-as-SharedSupport copy/clone policy, expansion and safety margin.
The 12.21 GB research package is retained in the temporary directory; no automatic deletion is
claimed. No proof about a recent macOS package is inferred from this Ventura sample.
