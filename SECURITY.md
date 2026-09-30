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

1. **Minimal, typed helper API.** The helper can only format a drive, run `createinstallmedia`, and report progress. There is no "run this command" function and no shell: fixed executable paths and arguments passed as arrays.
2. **Mutual code-signing checks over XPC.** The helper only accepts connections from the Relente app signed by the same team, and the app only talks to the genuine helper. Hardened Runtime and library validation are enabled.
3. **The helper re-validates everything.** The disk identifier must be a whole disk (`diskN`) that is external, removable, and connected over USB or SD, and it can't be the startup disk. Before erasing, the helper compares the disk's fingerprint (media UUID, serial number and size) with the one the user confirmed, to prevent time-of-check/time-of-use attacks.
4. **Only Apple-signed installers.** The installer app and its `createinstallmedia` tool must be signed by Apple, checked right before running them. Symbolic links are rejected, and disk images are mounted read-only.
5. **Administrator authorization for every erase**, with Touch ID or the user's password, through a dedicated Authorization Services right that the helper verifies.
6. **No networking in the helper.** Activity is logged with the unified logging system (`os_log`), and the helper can be uninstalled from the app.
