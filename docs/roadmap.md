# Roadmap

Updated November 11, 2026. Stable is [0.4.1](https://github.com/tvr-works/key/releases/tag/v0.4.1). This file owns the current plan; older design and qualification records describe the work at the time they were written.

## Next release: configuration cleanup

Working target: 0.5.0, because this changes deprecated CLI behavior. The scope below is a design, not implemented behavior or an announced legacy write cutoff. Keep the implementation, tests, release notes and small maintenance changes in one PR.

For a device-enrolled vault, the saved configuration should contain only its folder and vault ID. A local/iCloud Keychain choice does not control that vault's security or file syncing. The [configuration design](config-simplification-design.md#cfg-802-shorter-v3-file-with-a-bounded-legacy-path) specifies how to remove the leftover field without losing the old configuration needed to inspect retained legacy data.

| Change | Result |
|---|---|
| Stop writing `keychain_mode` for device-enrolled vaults | New setup, enrollment, migration and subsequent configuration saves produce the shorter file. Reading a config or installing an update never rewrites it. |
| Preserve an existing config before shortening it | Keep an exact, private local copy, including the original local/iCloud value. An unsuccessful preservation step leaves the active config unchanged. This copy cannot recover later vault contents. |
| Retire `config get keychain-mode` for device-enrolled vaults | Refuse with a short explanation and no stdout. Legacy vaults retain the setting until their migration path is retired. |
| Remove the deprecated `--totp` alias | `--totp-secret` remains the single spelling on add, edit, get and copy. Explain the change in release notes and the rejected-flag error. |
| Fold in maintenance | Use the verified shared `tvr-works-notary` profile, correct stale release/setup guidance, and record the published 0.4.1 result. |

Installing this release must not migrate a vault, change a recovery registration, administer a hardware key, or delete retained files. Older vaults remain readable and writable. No new persistent service, sync setting, vault format or recovery ceremony is needed.

Implementation should proceed in local commits: configuration representation and preservation, helper/CLI integration, then compatibility tests and release documentation. Use temporary homes and synthetic entries. Signed checks, if needed, use a separate disposable Preview installation. Do not use the owner's real vault or physical keys to qualify this change.

The required test matrix is in the configuration design. Release qualification must cover the shorter file, an already-migrated config retaining `icloud`, the old-writer round trip, failures before and after config publication, helper invalidation, and unchanged source entries. Run the usual PR checks and the migration-scale gate because migration selection changes. Choose live checks only for behavior that software tests cannot establish, particularly signed helper restart and reopening the saved selection.

## After that: retire ordinary legacy writes

The warning stage has shipped. Before disabling legacy content writes, announce the actual cutoff release and document the migration route for users who skip releases. Enforce the restriction in the helper; retain reads, authentication, diagnostics, root correction and explicit migration. Review administrative operations individually so the restriction cannot block migration preparation.

Qualify both legacy key-storage modes, interrupted migration, unavailable hardware, and moving the other Macs to the enrolled vault. Hardware-key purchase must not become a migration requirement. Do not combine this cutoff with the initial config cleanup merely to reach 1.0 sooner.

## Before 1.0

Remove legacy vaults from normal operation and normal configuration choices. Keep a narrow, explicit importer that can inspect and migrate an existing legacy config without starting the ordinary legacy runtime. Prove that the importer can load an existing local/iCloud source key without creating or replacing it, preserve source bytes on failure, verify the destination before selecting it, and serve users upgrading directly from older releases. Existing migration code and tests are the starting point; the importer-only entry point still needs implementation and qualification.

The config archive is migration/inspection information, not a second authority for the enrolled vault. Losing or changing it must never cause automatic legacy fallback, key creation or trust adoption. Recovery of the current vault continues to require an enrolled Mac or a previously registered recovery key plus retained vault files.

## Other planned improvements

- [Live dashboard status](todo-dashboard-live-status.md), followed by a [small menu bar view](todo-menu-bar-app.md) sharing the same status model. These are proposals, not implemented features.
- Revisit the macOS PIN dialog that can remain open after a timed-out recovery operation. Manual Cancel is the accepted, documented workaround; this is not a new release blocker.
- Profile repeated verification during recovery before choosing a performance change. Successful recovery is qualified; faster recovery remains a separate improvement.
- Full `otpauth://` import is a possible convenience feature, with no release assigned. Base32 setup secrets already work. Password generation remains external and composable through stdin.

Local app cleanup removed the retired Preview/test apps recoverably. Disposable vaults, test credentials, build outputs and qualification records remain. Inventory those separately and agree on retention before deleting them; they are not part of the config cleanup's automatic behavior.
