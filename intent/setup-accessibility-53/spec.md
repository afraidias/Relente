# Window accessibility design

- Revision: 1
- State: Accepted
- Issue: [#53](https://github.com/afraidias/Relente/issues/53)
- Intent: [Accepted revision 1](intent.md)
- Approval: Owner, 2026-11-05, revision 1; conversation: “vale” in response to the explicit design acceptance request.

## Proposed behavior

Give the assistant window's content container the accessible name “Relente”, the application's proper name in both English and Spanish. This name identifies the shared window without suggesting that every screen is the setup screen. It is for assistive technology; it does not add visible text or change the screen's visual design. Keep the existing screen headings, control labels and installation announcements intact.

Associate the accessibility change with the actual window hosting the assistant view using its view/window lifecycle. Do not select an arbitrary global window, such as `NSApplication.shared.windows.first`. Apply it again when a new hosting window is attached, and avoid modifying unrelated windows. Validate that the name does not cause redundant or confusing VoiceOver announcements; revise the approach if it does.

The implementation may bridge to AppKit because the investigation found that a label on the inner SwiftUI container does not name the outer window group. Use the smallest native bridge that can reliably identify the hosting window; do not introduce a dependency or silence audit results. Consult Apple's [accessibility audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) and [AppKit accessibility protocol](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol). No visual HIG exception is proposed.

## Acceptance criteria

1. On macOS 27, a reproducible UI check verifies that the previously unnamed outer group is identified and that the setup actions remain accessible. Run the audit without suppressing findings and record any remaining findings accurately. Existing contrast issue [#25](https://github.com/afraidias/Relente/issues/25) can still cause the full audit to fail; do not describe it as passing unless it actually does.
2. Manually inspect VoiceOver and keyboard navigation in English and Spanish: the setup heading, notices, actions and installation start/ready announcements remain understandable; the window name is not confusing or excessively repeated. Check a subsequent assistant screen, closing/reopening the window and, if multiple assistant windows can be created, that each is correctly identified without affecting unrelated windows.
3. The visual appearance and setup actions remain unchanged. Exercise the relevant available light/dark and Reduce Motion checks; document actual results and any inability to verify.
4. Preserve helper security and simulated-data testing. No real disk operation or real permission change is needed.
5. Record the host and test results. The owner accepted proceeding on macOS 27 without blocking on unavailable macOS 26; macOS 26 runtime behavior and the separate System Settings checks in #53 remain unverified.

## Risks and alternatives

The group may be framework-owned, and setting its name could affect other accessibility behavior or be overwritten during window lifecycle changes. If per-window labeling cannot be made reliable or VoiceOver becomes less usable, stop and revisit the design rather than hide the audit result. The experiment does not establish that the finding is harmless or caused by an Apple defect.
