# Mist source comparison — 2026-11-02

Read-only review of Mist main at commit `e2067cc8f4f398b458c9c88a3569042e28659419`,
cloned into `/private/tmp/relente-mist-source-review`. Not compiled or executed. This is third-party
implementation evidence, not an Apple API/security contract or permission to copy its architecture.

- [RefreshView](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Views/Refresh/RefreshView.swift)
  filters Apple catalog products by InstallAssistantPackageIdentifiers, reads English Distribution
  metadata and extracts name/version/build plus hardware identifiers as text.
- [DownloadManager](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Helpers/DownloadManager.swift)
  owns a URLSessionDownloadTask, observes task progress, supports retries/resume and handles a
  cancelled error in its completion handler. It uses URLSession.shared, not softwareupdate fetch.
- [Validator](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Helpers/Validator.swift)
  checks package size and SHA-256 chunks when integrity metadata exists. Those checks are not
  the same as Relente's proposed strict full-app Apple-anchor check.
- [TaskManager](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Helpers/TaskManager.swift)
  creates/mounts a temporary disk image, prepares the installer there and exports the resulting
  app. [InstallerCreator](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Helpers/InstallerCreator.swift)
  sends installer -pkg ... -target <mountpoint> to its privileged helper with CM_BUILD=CM_BUILD.
  Thus package installation and its scripts run; this is not script-free payload expansion.
  It contains version-specific copy/remove workarounds, including historical /Applications work
  for 10.13–10.15 and a path correction for Catalina onward.
- The reviewed download/prepare/export flow does not perform the codesign --deep --strict
  app verification that failed for our Ventura sample. Repository search found optional signing
  of generated export artifacts, which is a different operation. Therefore Mist's flow does not
  demonstrate that the source app satisfies our proposed strict check. Do not call this a
  signature workaround or infer that installation repairs the obsolete resource envelope.
- [ActivityView](https://github.com/ninxsoft/Mist/blob/e2067cc8f4f398b458c9c88a3569042e28659419/Mist/Views/Activity/ActivityView.swift)
  requests transfer/task/process cancellation and dismisses the view. The download routine itself
  waits for its completion handler, but this UI path does not await all terminal states before
  dismissal. Reading code alone does not verify safe cancellation/cleanup after every race.

Implication: direct owned downloading and temporary-image staging are useful comparisons.
Adopting Mist's package installation would add privileged script execution and its side effects,
requiring a different accepted security design for Relente. Its helper accepts command arguments;
Relente must preserve its own minimal typed-operation boundary. No Mist code/dependency was added,
no signing rule weakened and no change in preparation direction accepted by this comparison.
