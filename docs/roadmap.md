# Roadmap

Updated November 12, 2026. Stable is [0.4.1](https://github.com/tvr-works/key/releases/tag/v0.4.1). This file owns the current plan; older design and qualification records describe the work at the time they were written.

## Next release: configuration cleanup

Working target: 0.5.0, because this changes deprecated CLI behavior. The scope below is implemented locally on `codex/maintenance-cleanup` and remains unreleased. No legacy write cutoff is announced. Keep the implementation, tests, release notes and repository cleanup in one PR.

For a device-enrolled vault, the saved configuration should contain only its folder and vault ID. A local/iCloud Keychain choice does not control that vault's security or file syncing. The [configuration design](config-simplification-design.md#cfg-802-shorter-v3-file-with-a-bounded-legacy-path) specifies how to remove the leftover field without losing the old configuration needed to inspect retained legacy data.

| Change | Result |
|---|---|
| Stop writing `keychain_mode` for device-enrolled vaults | New setup, enrollment, migration and subsequent configuration saves produce the shorter file. Reading a config or installing an update never rewrites it. |
| Preserve an existing config before shortening it | Keep an exact, private local copy, including the original local/iCloud value. An unsuccessful preservation step leaves the active config unchanged. This copy cannot recover later vault contents. |
| Retire `config get keychain-mode` for device-enrolled vaults | Refuse with a short explanation and no stdout. Legacy vaults retain the setting until their migration path is retired. |
| Remove the deprecated `--totp` alias | `--totp-secret` remains the single spelling on add, edit, get and copy. Explain the change in release notes and the rejected-flag error. |
| Fold in maintenance | Use the verified shared `tvr-works-notary` profile, correct stale release/setup guidance, and record the published 0.4.1 result. |

Installing this release must not migrate a vault, change a recovery registration, administer a hardware key, or delete retained files. Older vaults remain readable and writable. No new persistent service, sync setting, vault format or recovery ceremony is needed.

Local commits cover configuration preservation, helper/CLI integration, compatibility tests and release documentation. Verification uses temporary homes and synthetic entries. Signed checks, if needed, use a separate disposable Preview installation. Do not use the owner's real vault or physical keys to qualify this change.

The required test matrix is in the configuration design. Release qualification must cover the shorter file, an already-migrated config retaining `icloud`, the old-writer round trip, failures before and after config publication, helper invalidation, and unchanged source entries. Run the usual PR checks and the migration-scale gate because migration selection changes. Choose live checks only for behavior that software tests cannot establish, particularly signed helper restart and reopening the saved selection.

The released-source 0.4.1 probe passed the config round trip: the old writer reintroduced `local`, the new writer removed it, both exact config versions remained archived, and the selected vault ID stayed unchanged. The final 146 focused tests, 300-entry migration case, strict build, unsigned Preview bundle/help/Tab checks, script checks, lint and dependency verification passed.

The broad software run was not clean: 31 tests failed around protected-file writes, and two wording assertions needed updating. The final focused run passed those updated assertions. An unchanged released-source test also reproduced a protected-write failure, but later the same native probe and all 31 tests passed on both versions without changing protection options. The condition is intermittent and its cause remains unresolved. Keep that limit visible; require a clean CI run and the scoped release checks before shipping.

## After that: retire ordinary legacy writes

The warning stage has shipped. Before disabling legacy content writes, announce the actual cutoff release and document the migration route for users who skip releases. Enforce the restriction in the helper; retain reads, authentication, diagnostics, root correction and explicit migration. Review administrative operations individually so the restriction cannot block migration preparation.

Qualify both legacy key-storage modes, interrupted migration, unavailable hardware, and moving the other Macs to the enrolled vault. Hardware-key purchase must not become a migration requirement. Do not combine this cutoff with the initial config cleanup merely to reach 1.0 sooner.

## Repository cleanup audit, November 12

The same branch also covers a wider source/tooling/documentation audit. This removes unreachable shipping code and makes historical test support explicit; it does not retire supported legacy vault operations.

| Finding | Disposition |
|---|---|
| Old alpha migration engine and destination/report branch | Removed. The live factory already uses the device-wrapped installer. Its interruption, source-change and empty-key tests remain; the blocked-preflight publication test was ported onto that installer. Config-selection and helper-serialization tests remain. |
| Unused runtime facade and two single-step catch-up wrappers | Removed. Tests now call the step services used by the live coordinator, which still owns mutation serialization. Cancellation, checkpoint, cache and session-lock coverage is retained. |
| Historical manifest/mutation/publication/recovery generators | Moved out of the shipping library into explicitly named `Legacy…Fixture` test support. Shared contracts, errors, object keys, readers and filesystem code remain in production. Historical compatibility and filesystem crash/corruption tests remain. |
| Provider-name policy with no production callers | Removed with its standalone tests. It was not an enforced product safeguard; actual name validation, legacy filesystem containment and current object-addressing rules remain. |
| Experimental recovery aliases and bundle override | Removed. Shipping and qualification builds use `KeyRecoveryEnabled`; qualification derives it from the explicit isolated-build choice and rejects stale flags or inconsistent components before installation. |
| Homebrew token wrapper and root-only config accessor | Removed after confirming no callers. Release targeting still has one canonical resolver; the helper uses the complete runtime selection. |
| Historical plans mixed into current docs | Moved under `docs/history/` with updated links and a historical notice. The documentation index identifies current guides, contracts and release ownership. |
| Secret-scanner false positives after file/type renames | Kept exact-expression exceptions for the renamed synthetic fixture and the historical prose path. The scanner probe verifies both old/new document paths and continues to detect and redact removed synthetic credentials in every affected file. |

All scripts were checked against repository callers; active build, install, release and qualification tools remain. The remaining one-reference app type is the SwiftUI entry point. The window-close delegate callback remains because AppKit invokes it. Two public library conveniences, `EntryStore.defaultRootURL` and `KeyConfigStore.listValues`, remain valid API; absence of repository callers alone does not prove external clients do not use them. No private helper without a lexical caller was found in the final source scan.

Supported legacy reads/writes, key lookup, migration preflight, device enrollment, authenticated codecs and refusal boundaries remain. This audit does not delete retained local vaults, credentials, build outputs or qualification evidence. CI and the release checks above still apply after the cleanup.

Audit verification passed 127 compatibility, migration, catch-up and unlock tests plus 75 current publication, mutation and ownership tests. The strict Swift test build, unsigned Preview Release build and bundle, CLI help and real Tab-completion checks, formatting, static analysis, 47 CI-script tests, release/install-script checks and dependency verification passed. All 1,913 discovered test declarations belong to a configured CI group; all 321 checked relative Markdown file links resolve. These targeted results do not replace the clean CI run required above. No installed app, real vault or physical key was used.

## Before 1.0

Remove legacy vaults from normal operation and normal configuration choices. Keep a narrow, explicit importer that can inspect and migrate an existing legacy config without starting the ordinary legacy runtime. Prove that the importer can load an existing local/iCloud source key without creating or replacing it, preserve source bytes on failure, verify the destination before selecting it, and serve users upgrading directly from older releases. Existing migration code and tests are the starting point; the importer-only entry point still needs implementation and qualification.

The config archive is migration/inspection information, not a second authority for the enrolled vault. Losing or changing it must never cause automatic legacy fallback, key creation or trust adoption. Recovery of the current vault continues to require an enrolled Mac or a previously registered recovery key plus retained vault files.

## Other planned improvements

- [Live dashboard status](todo-dashboard-live-status.md), followed by a [small menu bar view](todo-menu-bar-app.md) sharing the same status model. These are proposals, not implemented features.
- Revisit the macOS PIN dialog that can remain open after a timed-out recovery operation. Manual Cancel is the accepted, documented workaround; this is not a new release blocker.
- Profile repeated verification during recovery before choosing a performance change. Successful recovery is qualified; faster recovery remains a separate improvement.
- Full `otpauth://` import is a possible convenience feature, with no release assigned. Base32 setup secrets already work. Password generation remains external and composable through stdin.

Local app cleanup removed the retired Preview/test apps recoverably. Disposable vaults, test credentials, build outputs and qualification records remain. Inventory those separately and agree on retention before deleting them; they are not part of the config cleanup's automatic behavior.
