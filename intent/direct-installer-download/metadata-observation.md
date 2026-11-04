# Current-Mac metadata observation — 2026-11-02

Research evidence only; no implementation or accepted design. Environment: arm64, macOS 27.2
(build 26B123). Hardware model lookup was denied by the sandbox; no model-specific claim is made.

`softwareupdate --list-full-installers` initially produced no output in the sandbox. After
identifying the owned CLI process, it was terminated with SIGTERM; no update service was stopped.
A retry outside the sandbox, wrapped in a 45-second subprocess timeout, exited 0. No fetch was
requested. The listing contains 21 unique version/build pairs, each mapping to exactly one of
the 21 previously observed InstallAssistant catalog candidates. All candidates have
`InstallAssistantPackageIdentifiers` and exactly one package ending in `/InstallAssistant.pkg`.
All observed package URLs use `swcdn.apple.com`; English Distribution XML uses `swdist.apple.com`.
The additional XML reads used four concurrent requests, 15-second request timeouts, a 1 MiB
per-response read limit, exact HTTPS metadata origin checks and no redirect following. XML was
parsed as data only. This is a snapshot of observed structure, not a documented catalog contract.

| Version | Build | Product | Package bytes |
| --- | --- | --- | ---: |
| 27.2 | 26B123 | 142-50055 | 17807147403 |
| 27.0.1 | 26A434 | 142-27367 | 18386308006 |
| 27.0 | 26A428 | 142-15488 | 18400314350 |
| 26.7.2 | 25G332 | 142-50020 | 18389893051 |
| 26.7.1 | 25G241 | 142-28081 | 18380974544 |
| 26.7 | 25G229 | 142-16670 | 18381960622 |
| 26.6.2 | 25G83 | 140-93587 | 18384624402 |
| 26.6.1 | 25G76 | 140-77964 | 18368573458 |
| 26.6 | 25G72 | 140-71750 | 18373464112 |
| 15.8.2 | 24H232 | 142-50013 | 15664531445 |
| 15.8.1 | 24H32 | 142-27431 | 15664523626 |
| 15.8 | 24H23 | 142-16660 | 15664077639 |
| 15.7.9 | 24G830 | 140-85388 | 15655958320 |
| 15.7.8 | 24G824 | 140-71763 | 15655690961 |
| 14.8.9 | 23J631 | 140-88558 | 13654790295 |
| 14.8.8 | 23J620 | 140-75436 | 13654004934 |
| 13.7.8 | 22H730 | 093-22004 | 12205110942 |
| 12.7.6 | 21H1320 | 062-40406 | 12409187001 |
| 12.7.4 | 21H1123 | 052-60131 | 12408638012 |
| 11.7.11 | 20G1443 | 047-32248 | 12413681835 |
| 11.7.10 | 20G1427 | 042-45246 | 12416490165 |

The largest difference between the CLI's integer KiB value multiplied by 1024 and catalog bytes
is 1,013 bytes, consistent with rounding in this sample. Use version/build as identity and
catalog bytes as the observed transfer size; do not use approximate size as an identity key.
This establishes an observed exact join on this Mac, not a universal compatibility guarantee.
Unavailable, deferred, conflicting or missing-identity entries must remain ineligible. Refresh
both sources before acquisition; a stale snapshot cannot authorize a different product.

## Proposed preparation experiment budget

Candidate: product `142-50020`, Tahoe 26.7.2 / 25G332, declared package size 18,389,893,051 bytes
(18.39 GB / about 17.13 GiB). It is an exact current-Mac list match. The local volume reports
294 GiB available. Proposed provisional working budget: 70 GB total, comprising the package,
up to approximately twice its size for expansion/intermediate content, and remaining margin.
This is a planning allowance, not a verified expansion bound. Do not claim a free-space estimate
prevents archive expansion from exhausting storage. Before extraction, inspect verified archive
metadata and define an enforceable containment/storage limit or revisit this budget.

No package download or extraction has started. The next experiment would download only this
identified Apple package into a unique research directory, enforce the declared transfer limit,
record final origin/headers/hash, verify Apple package signer identity, inspect the package
structure without running scripts, then reassess extraction size/path safety. No installation,
privilege escalation for preparation, installer launch or write to /Applications is authorized
by this proposal. Package signature policy and safe extraction containment remain unresolved.

CLI output SHA-256: `71dac23b77a13dbd23276d220db4be537286e43fc5eff48d9844d08b356d280f`.
