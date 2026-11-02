# Guided flow and honest progress

Status: Accepted existing product decisions, consolidated 2026-10-29.

## Decision and rationale

Use a stable macOS assistant layout, one shared content width and system text styles. Keep the
footer stationary and show selection/navigation through spatial continuity. Reduce Motion replaces
travel and rolling animation with crossfades. Destructive actions never answer Return. Retry
returns to a fresh Review confirmation; after disconnection the destination must be selected again.

Show only progress measured from Apple's output or safe source/destination copy measurements.
Do not invent percentages, minimum display times or ETA. Unknown work uses an indeterminate
indicator. Completion requires verification. Keep compact activity in a popover and open complete
technical output in a separate window; reserve modal sheets for decisions. Output remains temporary.

Discover local installers in /Applications and allow explicit selection elsewhere rather than
request protected-folder access during discovery. Unknown drive contents count as data to be lost.
Show unsupported installers and too-small drives disabled with a reason. Product.md describes the
current screens and keyboard behavior; it is the authority for current presentation details.

## Consequences

Earlier simulated timings and weighted phases are not promises about live command output. The
root-owned package and permission decisions are documented separately. App identity uses the
approved ivory droplet/lowercase r on ink blue, with system masking and effects; do not bake tile
edges, highlights or shadows into foreground artwork. Icon previews are not supported-OS evidence.
