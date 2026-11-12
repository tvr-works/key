# Security, continuity and recovery

This is the security and recovery contract for device-enrolled vaults. Hardware recovery has been available since Stable 0.3.0. See the [recovery guide](recovery-user-guide.md) for setup and commands, and the [release record](release.md) for qualification results.

## File delivery and verification

Device-enrolled vaults have been directly tested on local APFS and in iCloud Drive. Other file-sync providers need compatible filesystem behavior and have not been directly tested. Every configured root must still pass Key's containment, type, atomicity, hydration and naming-safety checks. Key trusts authenticated, content-addressed vault history; provider ordering, timestamps and a claimed latest file do not establish authority.

Missing required objects prevent normal reads and writes from proceeding. An explicit `--allow-stale` read may use only the last complete version already trusted on that Mac. Malformed, substituted, rolled-back or authority-conflicting objects are security failures, not evidence that file syncing is merely slow. Key cannot prove that a provider has delivered every newer file or make it deliver deleted or withheld data.

## Keep another Mac enrolled

Each active Mac holds its own non-exportable Secure Enclave identity and has equal authority to enroll a new Mac or revoke another one after local authentication and explicit review. A file provider cannot enroll, revoke or impersonate a device.

With one surviving active Mac, you can enroll a replacement for a lost or revoked Mac. Keep another Mac enrolled for ordinary continuity. Recovery after losing every enrolled Mac requires a hardware key registered before that loss and retained encrypted vault files.

Inspect the authenticated roster with:

```sh
key share devices
```

## Invitations and device comparison

An enrollment invitation lasts 10 minutes and is bound to one vault, trusted checkpoint, inviting identity and new device. The joining Mac creates its own fresh identity and answers that exact invitation. Before approval, compare the displayed device pair and comparison code on the two Macs.

Provider delay does not extend an invitation or authorize a different ceremony. A joining Mac may finish only an exact approval that was durably prepared while the invitation was valid. Otherwise, create a new invitation.

## Revocation and replacement

Revoking a Mac rotates the vault key, re-encrypts the current snapshot and omits the revoked identity from new key wrappers. The revoked Mac keeps material it already possessed, but it cannot open the new current snapshot or future changes in that continuing vault.

If the revoked Mac returns, start a fresh invitation on a surviving active Mac and run the ordinary join command on the revoked Mac. Key displays a replacement review and requires the literal `REJOIN` confirmation before removing only that Mac's unusable local enrollment state. It revalidates the invitation immediately before cleanup. If helper restart exceeds the bounded wait, rerun the same join command; enrollment resumes from the saved state without repeating cleanup.

## What backups and recovery keys provide

The vault folder contains encrypted entries, authenticated manifests, public metadata, per-device wrapped keys and, when recovery is enabled, encrypted recovery information. It does not contain a plaintext vault key, cloud escrow or a support override. The sync provider cannot grant access by itself.

A registered recovery key can recover a retained vault without a surviving enrolled Mac. The hardware key does not hold the vault's entries: missing ciphertext still needs a file backup. Register independent primary and backup keys, keep them separately, and retain a separate backup of the complete encrypted vault. Ordinary access does not require either hardware key to stay connected.

Retained legacy entries can support inspection of an earlier migration source, but they do not recover later changes in the enrolled vault. The same limit applies to retained configuration copies. Neither is a replacement for a vault backup or a current access credential.

If every enrolled Mac is lost and no usable recovery key was registered beforehand, the encrypted vault files alone cannot restore access. Key will not generate a replacement key, silently trust provider files or offer a destructive repair that claims to recover the old contents.
