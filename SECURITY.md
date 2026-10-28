# Security

Relente erases disks through a helper that runs as root, so security issues are taken seriously.

## Reporting a vulnerability

**Please don't report security issues in public issues.**

Report them privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability**. You'll get an answer as soon as possible, and you'll be credited in the fix if you want.

Include what you found, how to reproduce it, and which version or commit you used.

## Supported versions

The project hasn't had a release yet. Once it does, only the latest release will receive security fixes.

## Security model

The app itself runs without privileges. Only a small helper, registered with `SMAppService`, runs as root. These rules are part of the design:

Live creation requires Full Disk Access for Relente and Background App Activity for its helper.
Installer browsing, download and drive selection remain available without Full Disk Access. At
Review, the helper validates the selected disk and makes a harmless temporary write check. If it
cannot write, Relente blocks creation before erasing and explains how to enable the required system
settings. Relente reports only progress observed from Apple's creation command; it does not present
whole-device write counters as installer bytes copied.

1. **Minimal, typed helper API.** The helper formats a drive and runs only the selected installer's Apple-signed `createinstallmedia`, with fixed arguments passed as an array. There is no "run this command" function and no shell.
2. **Mutual code-signing checks over XPC.** The helper only accepts connections from the Relente app signed by the same team, and the app only talks to the genuine helper. Hardened Runtime and library validation are enabled.
3. **The helper re-validates everything.** The disk identifier must be a whole disk (`diskN`) that is external, removable, and connected over USB or SD, and it can't be the startup disk. Before erasing, the helper compares the disk's fingerprint (media UUID, serial number and size) with the one the user confirmed, to prevent time-of-check/time-of-use attacks.
4. **Installer verification before creation.** The helper requires Apple's signature on the installer app and its `createinstallmedia` tool, checks them immediately before launch, rejects symbolic links and mounts disk images read-only. For `InstallAssistant.pkg`, the helper copies the selected package into a root-owned mode-0700 directory, verifies it with Apple's Software Update signer, and expands that copy without running package scripts. It uses only the helper-owned extraction, so the package signature authenticates the resources that `createinstallmedia` consumes and the logged-in user cannot replace them after validation. The helper may skip only legacy app bundle-resource validation for this extraction; the app code and `createinstallmedia` signatures are still checked.
5. **Administrator authorization for every erase** through a dedicated Authorization Services right. macOS offers Touch ID when available and falls back to the administrator password; the helper verifies the authorization independently before running `createinstallmedia`.
6. **No networking in the helper.** Activity is logged with the unified logging system (`os_log`), and the helper can be uninstalled from the app.
