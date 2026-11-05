# Clarify Relente setup

- Revision: 1
- State: Accepted
- Issue: N/A — screen review initiated by the owner
- Approval: Owner, 2026-11-04, revision 1; conversation: “acepto” in response to the explicit intent acceptance request.

## Problem and evidence

The setup screen combines helper installation, system approval, disk access and erase authorization in long blocks of text. The owner reported that the actions are difficult to distinguish and asked for an intuitive, comfortable flow.

## Audience and outcome

People preparing an installer should understand the helper's current state, the next available action, and where to find disk-access settings. The screen should remain understandable in English and Spanish, light and dark appearances, and with assistive technology.

## Scope and constraints

Review and improve the setup screen and its helper permission states, actions, errors and copy. Preserve the helper's security guarantees and existing supported platforms. Do not claim that Full Disk Access has been granted or denied without evidence. Each erase must still require administrator authorization. Review the applicable Apple guidance and validate the resulting interface.

## Non-goals

Other screens and an application-wide language selector are outside this change; the latter is tracked in [#51](https://github.com/afraidias/Relente/issues/51). Merge and release require separate authorization.

## Success measures

The next helper action is clear in each state; access to disk settings is discoverable without an unsupported status claim; recovery instructions are understandable; the reviewed states work with keyboard and VoiceOver, Reduce Motion, both appearances and both languages.

## Open questions and evidence

- Validate the exact wording and location of Login Items on supported macOS versions.
- Verify disk-access guidance and system-settings navigation against actual behavior and Apple documentation.
- Review all remaining states and accessibility behavior with the owner before design acceptance.
