# When Key cannot continue

Start with the command's exact error. A timeout or lost reply does not establish whether a change was saved. Keep the vault files, configuration and this Mac's saved operation records until the outcome is clear.

## Missing vault files

Check that your file-sync provider has downloaded the complete vault folder on this Mac. In iCloud Drive, use **Keep Downloaded**. Then run `key status` again, or `key-preview status` for Preview. Downloading files does not resolve conflicting access changes or a failed verification check.

## Conflicting entries

Run `key conflict list`, then `key conflict show <conflict-id>` to review the available versions. Use `key conflict resolve --help` before choosing which to keep. Replace `key` with `key-preview` when using Preview.

## Blocked vault history or failed verification

Key may refuse a vault when its history contains conflicting access changes, an unexpected older revision, or data it cannot verify. This is different from choosing between two edits to an entry.

1. Save the full error and the command that produced it. Record the app version with `key version` or `key-preview version`.
2. For a configured vault, run the matching command's `status --verbose` to inspect the reported problem. It does not edit entries or resolve conflicts and may ask for Mac authentication.
3. Keep the vault folder, configuration and local records unchanged. Do not delete files, run `init`, or choose a conflict version to bypass a security check.

There is no general repair command for these failures. If the error gives no supported next step, [report the problem](https://github.com/tvr-works/key/issues) with the version and error text. Remove private paths, entry names and other sensitive details before posting. Do not upload your vault, credentials or secret contents. A report does not guarantee that damaged or missing data can be recovered.

## Interrupted setup or recovery

Follow the failed command's resume instructions for the original attempt; see the [recovery guide](recovery-user-guide.md#if-recovery-is-interrupted). Use the same paths and IDs; do not start a replacement or delete saved records to retry.

If a PIN dialog remains after a timeout, cancel it without entering a PIN before continuing. If resume reports missing or changed records, stop and keep them intact. Save the error and app version as described above; repeated retries cannot recreate missing records.

Use an abandon command only when the error explicitly identifies an eligible early attempt and provides its original IDs. Abandonment is not a general reset or repair.

## This Mac has lost access

A Mac that still has access can invite this one again; see `key share --help` or `key-preview share --help`.

If no enrolled Mac is available, recovery requires a hardware key registered before access was lost and the encrypted vault files. See the [recovery guide](recovery-user-guide.md). The vault folder alone cannot restore access; there is no password or support override.

## Configuration save could not be confirmed (unreleased cleanup)

Run `key config list` to check which folder is currently selected. Keep the config file and any copies under `legacy-configs` beside it. Key preserves an older config before removing its obsolete Keychain-mode field; an unsafe, changed or oversized copy blocks that cleanup. Do not delete saved records or reinitialize the vault to bypass the error.

If the error says the original could not be preserved, Key did not replace the active config. Other save errors can occur after publication, so check the saved settings before retrying. The retained copies contain configuration only; they cannot restore current vault contents. See [configuration cleanup](../README.md#configuration-cleanup-unreleased) for their location and limits.
