# Setup screen design

- Revision: 2
- State: Accepted
- Issue: N/A — screen review initiated by the owner
- Approval: Owner, 2026-11-04, revision 1, “acepto”; revision 2, owner chose “Omitirla aquí” when asked about the erase-authorization explanation.
- Intent: [Accepted intent](intent.md)

## Working design

The owner preferred a direct primary action with a separate, visible control to open Full Disk Access settings. The screen must not report the disk-access permission as granted or pending without evidence. Use a prominent informational callout for the helper's current action and a quieter callout for disk access. Show success with a green check and installation errors with a circled cross. Each erase still requires authorization; omit its explanation from this screen as the owner requested.

Reviewed concepts include not installed, installation in progress, awaiting activation, helper ready and registration failure, plus light and dark appearances. English and Spanish copy and accessibility require further review. These concepts are not design acceptance.

When the helper is disabled during the flow, return to setup, explain that it is disabled, offer to open Login Items, and tell the user that their current selection is preserved. The owner agreed to this direction during the review; the complete design remains pending acceptance.

Accessibility direction reviewed with the owner: announce status changes without moving focus, support keyboard access to both actions, provide a static waiting indicator under Reduce Motion, and identify states in text as well as color and symbols. Verify these behaviors in the implementation.

Apple currently names the section [App Background Activity / Actividad en segundo plano de las apps](https://support.apple.com/es-es/guide/mac-help/mtusr003/27/mac/27). The owner preferred the contextual instruction above; verify the actual label and Relente entry on supported versions.

## Open design work

Confirm actual platform behavior, final bilingual copy, states and transitions including recovery and revoked approval, VoiceOver announcements, keyboard navigation, Reduce Motion, layout and contrast. Record Apple guidance, acceptance criteria and any deliberate HIG exceptions before requesting design acceptance.

## Requirements and acceptance criteria

1. Present a clear primary helper action for each state: install, installation in progress, open Login Items when approval is required, continue when ready, and retry after failure. Prevent duplicate registration while installation is in progress.
2. Keep a distinct action to open Full Disk Access settings and explain that access may be needed; do not represent its status as detected. Preserve the existing later write-access check and block before erasing if it fails.
3. Do not imply that setup itself erases a drive. Each erase continues to require administrator authorization; omit the separate explanation from this screen as requested by the owner.
4. If the helper is disabled on the installer, drive or review step, return to setup, retain the selections, and explain what happened. Do not interrupt an active creation.
5. On registration failure, offer retry and suggest checking the Applications folder if the problem persists; do not assert a diagnosis.
6. Present status in text as well as color and icon. Announce changes without moving keyboard focus, provide keyboard access to actions, and provide a static waiting indicator with Reduce Motion. Verify with VoiceOver and Accessibility Inspector.
7. Review final English and Spanish text and light and dark appearances, including long localized text and actual window dimensions.

## Apple guidance and limitations

Apple's [privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy/) recommends explaining access in context. [Service Management](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval) reports when the helper requires user action; the existing service uses Apple's Login Items settings entry point. Confirm the exact settings labels and navigation on supported macOS versions during verification. The disk-access statement is guidance rather than a detected permission state.

## Working copy

- Not installed: “Helper not installed” / “Ayudante no instalado”.
- Installing: “Installing helper…” / “Instalando ayudante…”.
- Approval: “Waiting for activation” / “Esperando activación”; “In the window that opens, find Relente under App Background Activity and turn it on. Then return here.” / “En la ventana que se abre, busca Relente en Actividad en segundo plano y actívalo. Después vuelve aquí.” The action opens System Settings.
- Ready: “Helper enabled” / “Ayudante activado”.
- Error: “Couldn’t install the helper. Try again. If the problem continues, make sure Relente is in your Applications folder.” / “No se ha podido instalar el ayudante. Vuelve a intentarlo. Si el problema continúa, comprueba que Relente está en la carpeta Aplicaciones.”
- Revoked: explain that the helper is disabled and current selections are preserved.

These strings are working copy; confirm system terminology and final layout before implementation. No HIG exception has been identified at this stage.
