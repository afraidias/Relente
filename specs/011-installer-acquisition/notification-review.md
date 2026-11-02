# User feedback and notification review

This inventory groups user-facing feedback by event. Labels, button titles and accessibility hints
remain in their context rather than generating separate notifications. Recommendations are for
review; only download cancellation currently requests a macOS notification.

| Event or message | Current presentation | Recommendation |
| --- | --- | --- |
| Download cancelled | macOS notification after a cancellation event | Keep, subject to the unresolved cancellation guarantee in the spec. |
| Download completed and installer verified | Installer becomes selected in the flow | Notify when the app is in the background; the user can continue when returning. |
| Bootable installer completed | Done screen, drive name and startup guidance | Notify when the app is in the background; keep the Done screen. |
| Download failed | Download screen with retry and a macOS notification | Keep the actionable recovery in the app and deliver a brief system notification, including while Relente is foregrounded. |
| Bootable installer creation failed | Error screen with reason, recovery and progress | Keep the error and recovery in the app; consider a brief background notification that the operation stopped. |
| Drive disconnected during creation | Error screen with recovery | Include in the creation-failure case above; retain the warning in the app. |
| User stopped creation | Error screen with recovery | No additional notification by default; the user initiated the stop. |
| Catalog unavailable, no compatible installers or catalog refresh | Download screen or loading state | Keep in the app; it is relevant while choosing a version. |
| Already downloading, catalog changed or ambiguous build | Download screen with recovery | Keep in the app; these messages explain the current action. |
| Multiple matching installers, local state unavailable or destination occupied | Download screen or Installer | Keep in the app so the user can resolve the specific conflict. |
| Installer invalid or unsupported | Installer status or alert with recovery | Keep in the app; the user is choosing an installer. |
| No USB drive, unsupported or too-small drive, disconnected or changed selection | Drive picker or review warning | Keep in the app; the choice and confirmation require attention there. |
| Helper missing, installing, awaiting approval, off or failed to install/uninstall | Permissions screen or alert | Keep in the app; the instructions and system settings are needed in context. |
| Full Disk Access or helper access required | Review alert or creation recovery | Keep the actionable details in the app. |
| Erase confirmation and authorization | Review screen and system authorization | Keep in the app/system authorization; never replace the explicit confirmation. |
| Formatting, copying, making bootable, verifying, remaining time and activity | Creation progress and activity window | Keep in the app; do not notify for each phase or percentage. |
| Drive ejection failed, force-eject confirmation | Done screen alert | Keep the actionable alert in the app. |
| Installers loading, no installers found or waiting for a selection | Installer/Download screen | Keep in the app; these are transient or contextual states. |
| How to boot, eject and start again | Done screen | Keep in the app; these are instructions and actions. |

Apple's [notification guidance](https://developer.apple.com/design/human-interface-guidelines/notifications)
recommends using notifications sparingly and retaining actionable error details in the app. Notification
delivery depends on macOS authorization and the user's notification and Focus settings. Download
failure and cancellation request system banners even when Relente is active, as requested by the owner.
