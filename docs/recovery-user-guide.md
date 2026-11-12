# Recovering a vault with a hardware key

Hardware recovery has been available in Stable since 0.3.0. The examples use `key`. For Preview, use `key-preview` with its separate configuration, Mac credentials and disposable vault. Try the recovery process with disposable data before relying on it.

A registered recovery key gives you another way to open your secrets if your enrolled Macs are lost. **You need both the recovery key and the encrypted vault files.** The hardware key does not contain a copy of your vault. Keep a separate backup of the complete vault folder.

Registering two independent keys lets either one recover the vault. Store them separately so one loss does not take both. Register and check each key individually; the original key can stay disconnected while you register its backup.

## Understand the approval prompts

Ordinary vault access uses macOS authentication, such as Touch ID or your Mac password, according to your Mac's settings. An unlocked session lets ordinary commands reuse that approval briefly; `key lock` ends it on this Mac.

Hardware registration and recovery add two distinct actions: enter the selected YubiKey's PIV PIN in the macOS dialog, then touch its metal contact when it flashes. That PIN is separate from your Mac password. Never put it in a command, configuration file or chat. Keep watching for the normal Mac approval prompts that follow until the command finishes.

Key reads the hardware key's public setup and requests its approval. It does not provision, reset or write to the physical key. Hardware setup and administration happen separately with the vendor's tools.

## Prepare and register each recovery key

### Hardware setup checklist

Use the vendor's tools to prepare each key separately before registration:

- Identify the physical key and check whether PIV slot **9d** is already in use. Do not overwrite an existing credential or reset PIV to make room.
- Set your own PIN and PUK. Keep them outside the vault you may need to recover.
- Protect PIV administration with a randomly generated, nondefault AES management key and management touch. Prefer PIN-protected storage on the key; otherwise, keep the management key safely offline. This affects the whole PIV application, not just slot 9d.
- Generate a **P-256** credential in the empty slot 9d with **PIN Always** and **Touch Always**, then create its matching certificate. These settings require PIN and touch for each use.

[Yubico's PIV instructions](https://docs.yubico.com/software/yubikey/tools/ykman/PIV_Commands.html) cover these operations. Enter credentials privately in the vendor tool's prompts, not in command arguments, environment variables, logs or chat. If a credential is unknown, stop rather than guessing or resetting the key.

Key's public inspection below checks reported settings; it cannot prove that administration is protected or that PIN and touch are enforced. For the design details, see the [hardware setup requirements](piv-recovery-contract.md#owner-operated-setup-boundary).

### Inspect and register

Connect the intended key and inspect it:

```sh
key recovery tokens
key recovery credential --token <token-id>
```

Replace `<token-id>` with the complete ID printed for that key. The credential check also prints a **recovery key ID**, used with `--recipient` (and called `recipientID` in JSON), which identifies its recovery public key. Use the full value, not a shortened prefix or certificate fingerprint. These public IDs are not passwords and do not authorize recovery. Public inspection does not test the key's private operation or prove that recovery will work.

On a Mac that already has access to the vault, update the vault format once:

```sh
key recovery adopt
```

Keep a complete backup and upgrade every participating Mac first. Older apps cannot open the updated format; returning to an older app requires your earlier backup. Updating the format does not register a key or activate recovery by itself.

Prepare registration for the connected key:

```sh
key recovery register prepare --token <token-id> --recipient <recipient-id> --export-anchor <new-file>
```

This saves a registration attempt on the Mac and exports a public recovery setup file, called an **anchor**. The output file must not already exist. Recovery is not active yet.

Install that exact file on the selected key using the vendor's [PIV object import](https://docs.yubico.com/software/yubikey/tools/ykman/PIV_Commands.html#ykman-piv-objects-import-options-object-data) operation. Key uses object ID **5F4B59** for this public setup record. Select the intended physical key explicitly and keep the other key disconnected. This writes the setup record, not a new private key or certificate.

Import only the file from this saved registration attempt, after `prepare` confirms the setup-record location is available. The vendor tool can overwrite an existing object; if its contents changed or an import result is uncertain, stop and inspect before another write. Never import a different file to force registration through.

Then finish registration with the same IDs:

```sh
key recovery register finish --token <token-id> --recipient <recipient-id>
key recovery register status
```

Finish checks the installed file and requests hardware approval. Enter this key's PIN in macOS, touch when it flashes, and approve the following Mac prompts. A successful registration makes this key available for recovery. Status lists the registered recovery key IDs, but does not exercise the physical keys or prove that all files have synchronized.

Repeat registration for the independent backup key, using its own IDs and a new setup filename. Do not overwrite the first key's setup. Before relying on a backup, check recovery from each key using disposable data.

If export fails, keep the saved attempt and use `key recovery register resume-export` with the same IDs and a new output filename. If another step is interrupted, follow its resume instructions. Do not delete records or prepare a replacement to force another attempt. `key recovery pending` lists saved operation IDs; their presence alone does not establish whether the operations finished or can resume.

## Recover after losing the Macs

Start with an unconfigured Preview installation, the encrypted source files and one registered key. The recovered vault will be separate from the source and will become this Mac's selected vault. It receives fresh Mac credentials and **does not inherit the source vault's recovery registrations**.

Connect the intended key and inspect it against the source folder:

```sh
key recovery tokens
key recovery review --source <source-folder> --token <token-id>
```

Review does not ask for PIN or touch and does not open secret contents. It checks the available public history against the key and prints the recovery key ID. A successful review is not proof that the contents can be recovered or that the provider has delivered every newer file.

Choose a destination that does not exist, with a parent folder that already exists. An existing empty destination is also refused. The source and destination cannot overlap.

```sh
key recovery restore --source <source-folder> --destination <new-folder> --token <token-id> --recipient <recipient-id> --name "Recovery Mac"
```

Enter the recovery key's PIN in macOS, touch it when it flashes, then approve the Mac prompts until completion. Key verifies the recovered contents before selecting the new vault. It leaves the source unchanged. The background service restarts before ordinary use.

Check the recovered entries, then lock and reopen the vault without the hardware key. Keep the source until you have verified the result. To protect the new vault with hardware recovery, follow the format-update and registration steps again as a separate setup. Retain any hardware setup still needed to recover an older vault.

### If recovery is interrupted

A timeout or lost reply does not prove that nothing changed. Keep the source, destination, configuration and saved records intact. Do not run init or start a replacement restore.

If macOS leaves a PIN dialog open after the operation stops, click **Cancel** before another attempt. The expired request cannot save a recovery result.

Use the original paths and IDs to continue a saved attempt:

```sh
key recovery resume --source <source-folder> --destination <original-destination> --token <token-id> --recipient <recipient-id>
```

Resume does not take a new Mac name or recreate missing records. If preparation stopped too early to resume, its error supplies the original vault and operation IDs. Follow `key recovery abandon --help` to release that early attempt. Abandonment preserves its files and credentials; a later new restore needs a different destination. If records are missing or invalid, stop and follow [troubleshooting](troubleshooting.md#interrupted-setup-or-recovery); do not delete them to retry.

## Add, remove or replace a Mac

Use the existing sharing workflow with the synchronized vault folder. On a Mac that already has access, use its recorded name to create an invitation:

```sh
key share devices
key share invite --name "Existing Mac"
```

On the joining Mac:

```sh
key share join <invitation-id> --name "Joining Mac" --vault-dir <existing-vault-folder>
```

Follow the displayed `requests`, `compare`, `approve` and `accept` steps. Compare the exact code and both Mac names on the two screens before approving. Copying the folder or signing into the same cloud account does not grant access. The joining Mac checks the approved contents before selecting the folder. Hardware keys can remain disconnected.

Use `key share devices` to identify an enrolled Mac, then `key share revoke <device-id>` to review removing its access. Removal changes the encryption key for the remaining Macs and recovery keys. It cannot erase secrets or older copies the removed Mac already obtained.

A removed Mac can rejoin through a fresh invitation. Review and confirm replacement of its old local credentials, then complete the normal comparison and approval steps. If interrupted, continue the displayed workflow; do not delete saved records or initialize another vault.

## Remove a recovery key

Find its complete recovery key ID with `key recovery register status`, then run:

```sh
key recovery remove-recipient <recipient-id>
```

The hardware key can stay disconnected. Review the ID and the number of recovery keys that will remain. Type `REMOVE` to confirm. Removing the last key requires `REMOVE LAST RECOVERY KEY` after the warning. Register another while an enrolled Mac is available; otherwise, losing all enrolled Macs leaves no recovery path.

Removal protects future versions of the continuing vault. It leaves the physical key and its anchor unchanged and cannot revoke access to retained older copies. If an ID begins with `-`, put `--` before it on the command line.

If removal was saved but a local completion step remains, keep the records and run the same command again to review and finish that removal. An uncertain reply does not prove that removal failed. Key does not retry automatically or start a replacement removal during resume.

## What the protection depends on

Key verifies access, encrypted contents and saved history itself. Your sync provider delivers the files. Key refuses visible conflicts and required missing data, but cannot prove that a provider has delivered every newer file. Keep complete backups: a hardware key cannot recreate deleted ciphertext.

Recovery checks a limited amount of history and data. Key refuses operations that exceed those limits; it does not silently discard older recovery records or reset a key's starting point. These safeguards are not a promise of a particular number of entries or years of use.

Physical testing covers two Apple silicon Macs on macOS 27.0.1 and two independently prepared YubiKey 5C NFC keys on firmware 5.8.0. The broader macOS 26+ and compatible firmware 5.3+ requirements are compatibility targets, not a tested device matrix. See the [release readiness record](0.3.0-release-readiness.md) for qualification scope and limits, and the [release record](release.md) for shipped results.
