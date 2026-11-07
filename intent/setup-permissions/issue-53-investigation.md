# Issue #53 investigation

Revision: 1
State: Investigation; no implementation approved
Related issues: [#53](https://github.com/afraidias/Relente/issues/53), [#25](https://github.com/afraidias/Relente/issues/25)
Date: 2026-11-05

## Environment and scope

Investigated the merged setup screen at `caa6eeabd6fa9f8b6ffb45c7b66f4fb35cc22f14` in an isolated worktree on macOS 27.2 (26B123), Xcode 27.1 (27A9275). UI tests used simulated data and the project's normal signing settings; no disks were operated on and no real permissions were changed. Temporary test and app changes were removed after the experiments. The owner confirmed that a Mac or virtual machine running macOS 26 is not available.

## Findings

- The setup screen's accessibility audit reports an unnamed disabled group covering the window. The reported disabled trait is not evidence that the controls themselves are disabled. The owner previously confirmed that VoiceOver reads the title, notices and buttons and automatically announces the simulated installation's start and completion.
- A minimal SwiftUI view with a text and a button in the app's existing window also produces the unnamed outer group. Removing the hidden title bar or labeling the SwiftUI content container does not remove the finding. This suggests the finding is associated with the enclosing window hierarchy, but does not establish an Apple defect or show that it has no accessibility impact.
- As a diagnostic experiment only, assigning a label to the AppKit window's content view changed the result: the minimal view passed, and the setup view's unnamed-group finding disappeared. On the setup view the audit then reported a subtitle contrast finding. This is not a production-ready fix: the experiment used `NSApplication.shared.windows.first`, a fixed English label, and did not validate window lifecycle, multiple windows, localization, or VoiceOver navigation. A contrast-only audit independently reproduced the subtitle finding; existing issue [#25](https://github.com/afraidias/Relente/issues/25) covers secondary-text contrast.
- Apple documents [SwiftUI accessibility containment](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain), [AppKit accessibility properties](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol), and [accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app). Passing an audit does not replace assistive-technology testing.

## macOS 26 evidence and limitation

The current source uses `SMAppService.openSystemSettingsLoginItems()` for Login Items; [Apple documents that API](https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems%28%29?language=objc). Apple's installed SDK header `EndpointSecurity/ESClient.h` lists the Full Disk Access System Settings URL used by Relente for macOS 13 and later. Apple's macOS 26 user guides describe [Login Items](https://support.apple.com/es-es/guide/mac-help/mh15189/26/mac/26) and [privacy settings](https://support.apple.com/es-es/guide/mac-help/mchl211c911f/26/mac/26). These sources support the intended destinations but do not establish that Relente opens the correct panes or works with VoiceOver on macOS 26.

GitHub documents a [macOS 26 hosted runner](https://github.com/actions/runner-images); its suitability for interactive accessibility and System Settings testing has not been established. The existing CI configuration does not constitute evidence of those checks. Access to a macOS 26 environment remains necessary for the outstanding runtime verification. On 2026-11-05 the owner accepted proceeding using macOS 27 without blocking on macOS 26 availability; this does not establish the result on macOS 26.

## Recommended next step

If the owner wants a fix, review and accept a separate intent, design and implementation plan first. Evaluate a correctly scoped, localized window-content accessibility label and its effect on VoiceOver and keyboard navigation; do not adopt the diagnostic `windows.first` code or suppress the audit. Keep the contrast issue and actual macOS 26 verification visible as separate outstanding work. Issue #53 is not resolved by this investigation.

## Local evidence

The diagnostic patch is saved at `/private/tmp/relente-issue53-diagnostic.patch`. The original setup audit, minimal-view variations, AppKit experiment and independent contrast audit are recorded in `/private/tmp/relente-issue-53-derived/Logs/Test/` and `/private/tmp/relente-issue53-*.log`; these temporary paths are not durable project artifacts. Audit failures were intentionally retained during the experiments and not suppressed.
