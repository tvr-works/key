# Signed Preview recovery qualification

Installed-product checkpoint: 2026-10-26; backup-key preparation added 2026-11-03. This is a scoped evidence ledger and remaining
native-test boundary, not a claim that the entire feature is qualified.
[Plan](piv-recovery-plan.md) owns completion gates; [contract](piv-recovery-contract.md)
owns security guarantees. Use disposable data only. No test result authorizes
another authentication, hardware write, reset, installation or real-vault use.

The [November 2 reconciliation](piv-recovery-plan.md#release-reconciliation-2026-11-02) compares this historical native evidence with later source changes and current software tests. It records no additional PIV hardware pass; the original build identities and limitations below remain intact.

The [November 3 preparation review](piv-recovery-plan.md#preparation-review-2026-11-03) and [next-session runbook](piv-recovery-qualification.md) add software coverage and a separately identified, uninstalled Debug candidate. They do not add a native result to this ledger or authorize changes to the retained first-key registration.

## Backup-key preparation, 2026-11-03

With the first key disconnected, the owner completed initial PIV setup on a second YubiKey 5C NFC, firmware 5.8.0, using YubiKey Manager 5.9.2 in their own Terminal. Initial public inspection found default PIN/PUK/management credentials, an empty slot 9d, no slot certificate and no recovery anchor. The owner changed PIN and PUK, generated a random AES192 management key with PIN-protected storage and touch, generated a P-256 credential in slot 9d with PIN/touch ALWAYS, and created its self-issued certificate with a new CHUID. Secrets were entered into vendor prompts, not supplied to Key or this chat.

Subsequent public reads reported nondefault PIN/PUK/management credentials, management touch ALWAYS and PIN-protected storage, generated ECCP256 origin, and PIN/touch ALWAYS for slot 9d. The saved public key, slot metadata and certificate public key matched. Local public-key verification validated the certificate signature; the subject is `CN=Key Recovery Backup`, with validity from 2026-11-03 through 2036-10-31. CHUID is present and the recovery anchor remains absent. PIN/PUK counters were both 3/3 and unchanged during verification.

This completes owner-operated credential preparation, not Key registration or recovery qualification. Reported generation origin is not independently verified attestation; public management flags do not prove secret custody or enforcement. No Key product authentication/agreement, anchor import, vault mutation or app installation occurred in this setup session. The first key remained disconnected and Stable was not accessed. The next gate is the explicit test-vault/current-app plan, then registration prepare/export, owner-run anchor installation and finish before either-key recovery tests.

Local public inspection and setup verification records are retained in `.build/piv-second-key-inspection-20261103/public-inspection.json` and `.build/piv-second-key-setup-20261103/public-setup-verification.json`. The latter records public-key/certificate/CHUID hashes, exact certificate dates and observed policy. The saved `recovery-public.pem` contains only the public key; neither the certificate nor that file grants vault recovery by itself.

## Backup registration preparation, 2026-11-03

The owner authorized preparing the test app and adding the second key to the existing disposable vault, preserving the first key and Stable. The old Preview selection pointed into the removed `6d7b` worktree. Its encrypted source survived in the iCloud build25 transfer packet: `EditedRotatedSource.zip`, SHA-256 `9d2ceb56b323e651c0385c97a1a73ba794cfa9072c38de917fee8d2419b81823`. A narrowly scoped, signed, noninteractive diagnostic confirmed that Preview's original Mac identity record remained present and its public checkpoint matched the packet's exact head `5OWl0GLLlIzLqxyoEPbYaNK5dxcBiWJ4EIlC2WSeuEY`, vault `8b67cabc-7c4a-4eae-a67e-edc06cf47ea4`. No private identity data was exported and no checkpoint was replaced.

After backing up Preview25 and its support/configuration, 22 path- and digest-validated published files were restored to `Key Preview Vault/recovery-qualification-2026-11-03/vault` in iCloud Drive. Preview was explicitly selected onto that same vault using its retained Mac authority. The former restored-vault selection and its local records remain preserved in the receipt. This was filesystem recovery of the existing test source, not creation of a replacement vault or a hardware restore with the first key.

The installed candidate is private PreviewRelease build27, marketing version 0.2.0, source `661c69e`, with temporary app/helper recovery opt-in plists supplied before the normal Xcode archive/signing process. Strict Developer ID signatures, timestamps, entitlements and product checks passed. The owner explicitly approved sending the compiled app to Apple after automatic approval review initially blocked the upload. Notarization submission `61bc86af-0c1f-4ccd-ac22-69d022e45d7e` was Accepted; stapling and Gatekeeper passed. The app is not a published release. A preceding PreviewDebug build26 and a non-notarized build27 did not start the helper; captured registration state showed stale signing categories and Gatekeeper rejected the non-notarized artifact. Normal Preview-only unregister/install/register with the notarized archive resolved startup. No global background-item reset, signature bypass or helper-policy relaxation was used. These observations do not isolate each failure's cause.

The vendor tool initially saw the prepared second key while the installed product's public token list was empty. After the owner disconnected and reconnected only that key, public discovery and credential review succeeded, returning recipient `MI2m8GPlaZk-Fm6-BS5f5fIHxqFGl74sZVKyj9JrkaY` and an absent anchor. The recipient matched the independently derived ID from the saved public key. The vault had no pending selectors. Mac-authenticated status confirmed the first recipient `cxRS8dxO8OSY_hQqIh-bplLsch8K6BFWTuzcmgH3Qs4` remained the only active recovery recipient.

One authorized `register prepare` completed with Mac approval and exported a 401-byte public anchor. Operation `09c04a4a-62c2-4b7f-8e98-9c356cf4c8fe`, registration `5977e9b3-ddab-4c3b-b898-20a785c7ef30`, proposed manifest `y0EiuH_MQNheruOis6Eguyuy54NsFZkCl5hmA3tzYVE`; anchor SHA-256 `7e1eaa3ea3197bf9eb6610124f0e411c4cd1cda7be7c7f7e3afc52aa801267e7`. Public postchecks confirmed the second key's credential/certificate unchanged, anchor still absent and PIN/PUK counters both 3/3. All 332 Stable file/registration checks and all 22 original published files matched their baselines. The first key stayed disconnected throughout.

At the preparation checkpoint, exactly one saved registration awaited owner-run import and `register finish`; the second key was not active recovery protection yet. The activation result follows below. Complete records, rollback ZIPs, candidate/component hashes, signing/notary logs, source inventory, public selectors and preservation results are under `.build/piv-backup-registration-20261103/`; the export is `backup-anchor.json`.

## Backup registration activation, 2026-11-03

The owner imported the prepared public anchor into the second key with the vendor tool. Readback matched all 401 exported bytes and SHA-256 `7e1eaa3ea3197bf9eb6610124f0e411c4cd1cda7be7c7f7e3afc52aa801267e7`; Preview recognized the anchor and the expected recipient. The public credential, certificate and reported PIN/touch policies remained unchanged. These checks required no device authentication or writes.

After the owner confirmed readiness for Mac approval, native PIN entry and touch, one `register finish` succeeded in the installed private Preview27 artifact described above. The CLI reported hardware approval completed, recovery setup committed, the expected vault ID and manifest `y0EiuH_MQNheruOis6Eguyuy54NsFZkCl5hmA3tzYVE`, with cleanup pending false. A subsequent authenticated registration status reported both expected recipients registered; pending discovery returned no operations. The first key remained disconnected throughout.

Postchecks confirmed all 332 Stable file/helper-registration checks and all 22 original published test-vault files unchanged. The new manifest preserved the first recipient's full registration record, including its public key and registration ID, and added the second as active. The published source now contains 11 manifests and 15 encrypted entry versions. Public second-key checks again matched the imported anchor, credential and certificate, retained PIN ALWAYS/touch ALWAYS, and showed unchanged PIN/PUK counters. Evidence is retained in `import-verification.json`, `credential-after-import.json`, `finish.log`, `status-after-finish.json`, `pending-after-finish.json`, `key-after-finish.json` and `finished-result.json` under the preparation evidence directory.

The second key is now registered for this disposable vault. This completes the backup-registration portion of Q1, including native possession verification, while preserving the original recovery registration. Independent restores with each key, followed by the remaining lifecycle and release qualification, are still required; no full two-key recovery or release pass is claimed.

## Independent recovery with the backup key, 2026-11-03

The owner authorized separate recovery tests with each key while preserving Stable and both tokens' existing setup. With both keys disconnected, private Preview27 verified the retained source values, edited a test secret and authenticator seed, completed one encryption-key rotation, then edited the secret again and added another entry. The final source has four current entries, 16 manifests and 22 encrypted entry versions, at head `GPFsg_TJzAa-64IEPydtJO_FSGwykfn5niWWfeZICsI`. The rotation changed the vault key, epoch authority and wrappers while preserving both recovery recipients and their generation. All previously published files remained unchanged. The source Preview selection stayed on the original disposable vault.

Two fresh PreviewDebug qualification apps were built from `69a0a2c`: build28, namespace `piv-second-1103`, and build29, namespace `piv-first-1103`. Their application/helper identities, service and support namespaces, recovery opt-in, helper smartcard entitlement and signatures were verified before use. Both helpers rejected ordinary status before configuration. Only published encrypted manifests and entry objects were copied to the recovery source folder; no source configuration, Mac credentials, checkpoint/cache or preparation records were supplied to either destination. The apps retain Preview's base Keychain access group and CLI signing identity, with separate service/account namespaces. This exercises namespace isolation on one Mac, not separate operating-system security principals or shipping-artifact qualification.

With only the second key connected, public inspection matched its saved credential, certificate and anchor. The isolated app reviewed the expected current head and its registration, then one restore succeeded through native PIN/touch and Mac approval. It restored four entries to vault `0deef174-80a1-4a93-ac03-8c05d8a2e3a9`. Postchecks found the token's credential, certificate, anchor and reported PIN/touch policies unchanged, with unchanged retry counters.

After both keys were disconnected, all three secret values matched exact expected CLI-output hashes, including an embedded newline. The authenticator code matched the retained synthetic seed within its measured read interval using an independent comparator checked against two public TOTP vectors. Status reported ready, four entries and no conflicts/issues. The destination has a fresh vault key and Mac device/signing/wrapping identity and no inherited recovery registration. All checks passed again after `lock` and a confirmed new helper process. The encrypted source snapshot remained unchanged, as did all 332 Stable file/helper-registration checks.

This passes the second key's independent recovery and token-free reopening after post-registration edits and rotation. The first key's equivalent test remains pending at this checkpoint. Evidence, exact bundle inventories, encrypted source inventory, test scripts and value-comparison results are retained locally under `.build/piv-independent-recovery-20261103/`. Synthetic plaintext fixtures stay outside the published-source folder and are not committed. Two preparation-script assumptions were corrected before continuing: piped `get` output adds no newline, and this macOS build's DER entitlements must be inspected with the current `codesign` output rather than its legacy XML option. Neither required a product change or a repeated hardware operation.

## Independent recovery with the original key, 2026-11-03

With the second key disconnected, public inspection of the original key matched the original recipient and registration in the encrypted source. Its public key, registration ID and anchor differed from the backup key's. Public review in the `piv-first-1103` app selected the same current four-entry source head through the original registration point `y6x1_pue0dRG8eWNQhMamkzdy2qkPVWV_HSkwjvH0w4`; the backup key had used its later registration point `y0EiuH_MQNheruOis6Eguyuy54NsFZkCl5hmA3tzYVE`.

The first restore completed native PIN/touch approval, saved preparation, published and selected destination vault `b69f64df-37b2-4b1a-95f2-dd3c655a4ff1`, then reached the CLI's 120-second response timeout during final Mac verification. The owner reported a missed or cancelled prompt. No automatic retry or replacement restore was made. After the isolated helper was locked/restarted, the product refused ordinary work and reported that the saved recovery required explicit resume or inspection. Operation `50d5bc8f-4ab5-4d30-9315-d0f046afa1d6`, its reservation/preparation, selected configuration and checkpoint were retained.

Following renewed owner readiness, one explicit resume with the original source, destination, token and recipient succeeded in 21.766 seconds, using fresh PIN/touch and Mac approval. The destination configuration and checkpoint manifest were byte-identical to those selected before the timeout. The resumed operation completed the same four-entry vault; it did not create a replacement identity or destination. Public first-key checks afterward exactly matched the pre-test credential, certificate, anchor, reported policies and retry state. This qualifies this selected-destination interruption/resume boundary, not every interruption phase in Q5.

With both keys disconnected, the original-key destination passed the same exact three-secret and independently checked TOTP comparisons, ready/four-entry/no-conflict status and fresh-authority/no-inherited-registration checks. These passed again after lock and a confirmed new helper process. The two destinations have different vault IDs and different device, signing and wrapping identities. All 332 Stable preservation checks passed; the continuing source and shared encrypted snapshot retained their complete file inventories during both restores. Both keys' public setup was unchanged. The source Preview and both destination test sessions were locked at completion; retained test data and records were preserved.

Q1 is now passed for these two independently generated YubiKey 5C NFC credentials on firmware 5.8.0, using the Mac mini on arm64 macOS 27.0.1 and the identified private Preview27/qualification28/qualification29 artifacts. Each key alone recovered the same current contents after post-registration edits and rotation, from its own unchanged original anchor, without supplying source-Mac authority to the destination namespace. This does not extend the OS/hardware support claim or replace final shipping-artifact and remaining lifecycle qualification. Evidence is in the same local directory, including `first-restore-result.json`, `first-timeout-support-files.json`, `first-resume-result.json`, both keys' before/after public inspections, each destination's ordinary/reopened verification and helper PID records, and `final-results.json`. No code change, push or release occurred in this test session.

## Editing a recovered vault, 2026-11-03

After Q1, the owner authorized editing a recovered vault and preparing the two-Mac lifecycle session, preserving Stable and both hardware keys. In the existing `piv-second-1103` build28 destination, vault `0deef174-80a1-4a93-ac03-8c05d8a2e3a9`, one secret was replaced with a synthetic multiline value containing a final newline. Exact piped output matched all bytes. The other two secrets retained their expected hashes, the authenticator code matched its retained seed within the measured read interval, and status remained ready with four entries and no conflicts or issues.

The same checks passed after `lock` and a confirmed new helper process. Both hardware keys were absent throughout; no device authentication or hardware operation was requested. The selected vault ID/path, prior immutable published files, original recovery-enabled source, encrypted Q1 snapshot and other recovered destination remained unchanged. All 332 Stable file/helper-registration preservation checks passed. The edited destination was locked at completion. Local scripts, hashes and results are retained under `.build/piv-lifecycle-prep-20261103/`, including `recovered-edit-result.json` and the ordinary/reopened verification records.

This closes Q4's ordinary edit/read/reopen portion. Registering recovery on the new vault and recovering it again remain separate work requiring a hardware-allocation plan that preserves both retained original anchors. It does not create or inherit recovery protection for the edited destination.

## Two-Mac lifecycle preparation, 2026-11-03

The owner authorized coordination with `key-piv-macbook-air` to prepare Q2. The Air's clean older checkout at `53bdb59` was left unchanged. A tracked-source archive from Mini commit `8f4c2b5`, SHA-256 `607272d990b6b1ab60532991c35d2bea00f4bae8c798e2b5ef848cfa106ad681`, and a build-only recipe were delivered through a fresh iCloud test-transfer folder. The Air verified the hash, archive member paths/types and source isolation before extraction. Its public source inspection saw the expected head, 16 manifests, 22 entry versions, four current entries and two recovery recipients. No source-Mac credentials, configuration, checkpoints or plaintext fixtures were transferred.

The current qualification script was invoked with PreviewDebug, recovery enabled, installation disabled, namespace `q2-lifecycle-air-1103` and private build30. On arm64 macOS 27.0.1 (26A434), Xcode 27.2 (27B52), Swift 6.4.2, the build exited65 during provisioning after 31.746 seconds: account login was rejected and a development profile for `work.tvr.key.preview.xpc.qualification.q2-lifecycle-air-1103` was unavailable. An unrelated-looking CoreSimulator version warning was also recorded; it is not the established fatal signing error. The owner was asked to refresh the Air's Xcode account before a normal retry. No signing bypass, installation, launch, authentication, enrollment or token operation was performed.

The Air reported all three existing app bundles and their support records preserved, extracted tracked source unchanged and the new app/support/default-vault paths still absent. Its evidence is retained under that chat's `q2-build30-preparation-20261103T192937Z/` directory and `q2-air-build30-preparation.json`. The [session runbook](piv-two-mac-lifecycle-session.md) fixes the intended app/source boundaries, deterministic controlled-delivery conflict checks, reviewed revocation and same-app `REJOIN`. These are preparation records, not a Q2 pass. Build30 remains reserved; no push or release occurred.

### Air preparation completed after account repair

After the owner confirmed Xcode sign-in was repaired, the same normal automatic-signing build30 recipe passed in 32.02 seconds. Tracked source remained unchanged; no manual profile override, rebuilt product modification or re-signing bypass was used. Verification checked exact app/helper/CLI identities, deep signatures, actual public signing certificates, DER-backed entitlements, helper smartcard access, the Preview Keychain group, namespace/service constraints and every bundle file hash. The helper's development profile `139a71fa-d473-402d-a452-454d4e14e782` included the Air and matched the signing certificate. A read-only verifier command initially passed the optional certificate-extraction prefix incorrectly; correcting it to `--extract-certificates=prefix` allowed the existing artifact's checks to complete without another build.

The verified artifact from `8f4c2b55b2b22f6579a6abbbdd44aaafa29d1213` was installed only at `/Applications/Key Preview Migration Qualification q2-lifecycle-air-1103.app`. Its own helper registered, ordinary status refused with “No vault is configured,” configuration remained absent, and its supported lock command stopped the helper. Existing Stable, Preview25 and prior qualification apps, support records, helper states and source inventory remained unchanged. The expected original Mini owner was rechecked in the source roster. No invitation, enrollment, vault authentication or YubiKey operation occurred.

The Air is ready for the later Q2 session, not qualified for its live lifecycle outcomes. Full evidence is retained on the Air in `q2-air-build30-verification-installation-corrected.json`, `q2-air-preparation-summary-20261103.json` and the preparation directory's `build30-full-bundle-hashes.json`; a copy of the returned readiness summary is retained on the Mini under `.build/piv-lifecycle-prep-20261103/air-ready-summary.json`. Private build30 is now used; the next candidate must use at least build31, subject to checking for newer private builds. No push or release occurred.

## Two-Mac enrollment, 2026-11-03

The owner authorized enrollment on the original disposable vault, with normal Mac approval on both machines and both YubiKeys disconnected. The Mini used the verified private Preview27; the Air used the verified isolated build30. Both preflights matched the original 38 published files and head `GPFsg_TJzAa-64IEPydtJO_FSGwykfn5niWWfeZICsI`, the sole Mini owner and both active recovery recipients. The Air had no selected vault or pending setup before joining.

One invitation and one Air join request were created. Independent comparisons matched the complete code `6acc-b3f2-987c-0911-31bf`, names `Tim’s Mac mini` and `MacBook Air lifecycle test`, vault ID, device identities and signed invitation/request file hashes. The new Air identity is `bL5KxnrX7YklHeQSFBQ7m073oBNg76cWlmC3ahxYS0o`. The Air remained unconfigured through comparison. Its metadata harness initially expected `requests/` instead of the actual `join-requests/<invitation>/` path; reading the already saved request corrected the evidence without repeating a native join or comparison.

The Mini approved the matched request successfully. Its authenticated checks then reported two active Macs, four current entries, no conflicts or pending operations, and both unchanged recovery registration records. Exact secret bytes and independently computed TOTP matched. The approved head is `Ze59_XIu_3VVq5ZsDZQItNIO3JHPErSg9qp24Qw1wFo`, with 17 manifests and 26 encrypted entry versions. All original published files and the Mini configuration remained unchanged.

The Air accepted exactly once, exiting successfully after 23.579 seconds and selecting that original vault path in its isolated configuration. Authenticated status and device inventory agreed with the Mini. All three secret hashes matched without newline normalization. The Mini independently verified the Air's TOTP fingerprint against the retained fixture seed and exact read interval; the comparator also passed public reference vectors. Both full recovery recipient descriptors and the recovery generation were unchanged. A second harness correction counted the captured device list rather than expecting a nonexistent `activeDeviceCount` JSON field; no acceptance, unlock, status or inventory command was repeated for that correction. No product failure was observed in this enrollment.

Enrollment is passed for these private artifacts. Concurrent edits, revocation, same-app rejoin and recovery of the resulting history remain separate Q2 outcomes. Mini evidence is retained under `.build/piv-two-mac-enrollment-20261103/`, including the exact comparison, approval, `enrolled.json`, `air-enrolled-summary.json` and independent TOTP result. Air evidence includes `q2-air-enrollment-request-20261103.json`, `q2-air-enrollment-acceptance-20261103.json` and `q2-air-joined-vault-verification-20261103.json` under its chat evidence directory. No hardware operation, push or release occurred.

### Ordinary delivery and reopening

After acceptance, the Mini added `lifecycle/enrollment-mini` and the Air received it through the original iCloud folder. Its exact 77 bytes, including embedded and final line breaks, matched. The Air then added `lifecycle/enrollment-air`; the Mini received and verified its exact 98 bytes in the same way. Each Mac made one new-entry mutation, with no overwrites or manual transfer of vault objects. Both new entries survived normal lock and authenticated reopening through fresh helpers on both Macs.

The final common head is `kNoWRIWK_fenjVHcal1vyqRwxk_23Q_PT-ZlS3O4GvQ`, with 19 manifests, 28 encrypted entry versions and six current entries. Both Macs reported ready status, no conflicts and no pending operations. The original secret hashes and independently verified TOTP remained correct. Both recovery recipients and the device roster were preserved. All older published objects, the Mini configuration, both Q1 recovered destinations and the frozen Q1 source were unchanged; all 332 Mini Stable checks passed, and the Air's protected apps/support records matched their baselines. Both test helpers were locked and stopped at completion. No hardware operation occurred.

This passes enrollment, ordinary bidirectional iCloud delivery and reopening for the tested artifacts. It does not qualify concurrent-write merging, conflict resolution, revocation, same-app rejoin or recovery of the final history. Final shipping-identity qualification also remains separate. Mini evidence includes `mini-delivery.json`, `air-delivery-summary.json`, both Air TOTP verification results, `mini-delivery-reopened.json`, `final.json`, `mini-preservation.json` and `session-result.json` under the enrollment evidence directory. The Air's full delivery and reopening record is `q2-air-enrollment-narrow-delivery-20261103.json`. No product code change was needed; work was committed locally without pushing.

## Concurrent edits and conflicts, 2026-11-03

The owner authorized these tests after enabling Keep Downloaded on both Macs. The existing Mini Preview27 and enrolled Air build30 used independent local copies of the exact common head `kNoWRIWK_fenjVHcal1vyqRwxk_23Q_PT-ZlS3O4GvQ`: 19 manifests, 28 encrypted entry versions and six current entries. Only published encrypted objects and manifests were copied. Each app selected its local copy with `config set vault-dir`, retaining its own enrolled identity and local records. No global sync setting, Stable vault or hardware setup was changed.

Each Mac added a different entry before either received the other branch: `lifecycle/mini-only` and `lifecycle/air-only`. Both branch manifests named the same original parent. Full encrypted inventories were exchanged through `Key Preview Vault/lifecycle-conflict-transfer-2026-11-03`, with file hashes, path checks, exact vault IDs and baseline inclusion verified before delivery. Existing immutable files were never replaced. This controls delivery to create reproducible competing histories; it does not test iCloud's natural conflict timing.

On the Mini, the two-head union contained no entry conflicts. One ordinary `add lifecycle/merge-marker` published an automatic merge naming both branch heads, then saved the new entry. Both independent values, every original value and TOTP verified afterward; health was ready with nine entries and no pending work. The full authority and recovery metadata matched the baseline. Merge manifest `c9503a80a5d76db405b5645d1b66dae7d70f1529f678f10a37823a2f985f00de` names parents `2e09610aa09c7b3b8c1521e0ce8960d619faa6b266db6d9683beaa355dbdf610` and `b92ffc9999ddcdfcf2b0b426663913f6c1eb7614793c83758273cfd4d986d411`; the following ordinary save is `80dc1ee3bf1ccddb41ef6ab402281ef9d217fdb8b639c03e6e2962da79104ff7`.

The Air independently validated the same two-parent merge, all eight secret values and the unchanged authority/recovery metadata. Its TOTP fingerprint matched the Mini's independent fixture calculation for the recorded interval. One expected backup-cycle checksum had been transcribed as 51 characters in the Air harness; the saved native result matched the previously verified 64-character baseline. The harness was corrected without repeating the completed product command. Both Macs therefore passed automatic merge and catch-up before the conflicting-edit stage.

### Explicit conflicting-value resolution

From the common merged head `80dc1ee3bf1ccddb41ef6ab402281ef9d217fdb8b639c03e6e2962da79104ff7`, each Mac independently edited `recovery-test/secret`. Both versions were revision6, with distinct exact values: 75 bytes from the Mini and 96 from the Air, each containing embedded and final line breaks. The branch heads were `efeb5478abe703585a9a5bf1a94de932a82f5af46524ab4bce19ff10830c0a0f` and `9e171080902299519f5701eac9d4fc13316d143c2b2ea9b5e6a2afcbd0750318`. Their complete encrypted inventories were retained separately.

After receiving both branches, the Mini reported exactly one `edit_edit` conflict. An ordinary read refused with exit4 and no plaintext output. Conflict review returned both exact values with distinct version IDs. One explicit resolution selected the Air version `9e17108090229951`; the new manifest named both conflicting parents and resealed that exact value at revision7. All eight secret hashes and TOTP then verified, with nine current entries, ready status, no conflicts or pending work, and unchanged full authority/recovery metadata. Every prior immutable object was preserved.

The resolved head is `FQ92t1ADBY6bLirc5jsddRMtuuH1Zk0GKrQ6upEiPjo` (hex `150f76b75003058e9b2e2adce63b1d75132dbae1f5664d062ab43aba91223e3a`), containing 26 manifests and 34 encrypted entry versions. The Mini added this complete verified union back to the original shared test folder, returned to that folder through the supported configuration command, and verified all values again after a fresh-helper reopen. Its 332 Stable checks, both Q1 destinations and frozen Q1 source remained unchanged. The Mini test helper is locked and stopped.

The Air independently observed the same conflict ID and two revision6 values. Its ordinary read also refused with exit4 and no plaintext; its previously-trusted flags correctly identified its own branch rather than the Mini's. It performed no resolution write. After importing the Mini's pinned resolution, all eight current secret hashes matched, including the chosen Air value, with revision7, ready status, no conflicts or pending work and unchanged authority/recovery metadata.

The config-return harness initially required byte-identical formatting. The supported writer correctly restored the same effective path, vault ID and mode but normalized its comment, trailing directory slash and final newline. Verification was corrected to compare path and setting semantics, reusing the successful publication/configuration result without repeating either action or manually overwriting configuration. The final serialized Mini configuration is retained in `source-config-final.toml` under the conflict evidence directory.

The Air then verified the exact 60-file resolved inventory at the original iCloud path, returned through its supported configuration command and reopened using a fresh helper. All eight secret values and TOTP verified again; the Mini independently checked the Air's authenticator fingerprint against the retained seed and read interval. The Air's original configuration bytes matched exactly. Both Macs finished with the same resolved head, nine healthy entries, no conflicts or pending work, and their test helpers locked and stopped. Stable and both keys remained untouched.

This completes Q2's controlled concurrent-edit, automatic-merge, explicit conflict-review/resolution and post-resolution reopening checks for Mini Preview27 and Air build30. Revocation, same-app rejoin and recovery of the final history remain open. Native source and transfer snapshots, exact-value fingerprints, command results and preservation checks are retained under `.build/piv-two-mac-conflicts-20261103/`, with the final outcome in `session-result.json`. Air command records remain in its chat evidence directory; the Mini retains the returned summaries and independent TOTP results in `air-merged-verification-summary.json` and `air-final-summary.json`. No product code change, push or release occurred.

### Wording issue found before automatic merge

An extra current-value read before merge publication refused with exit4 and “Saving changes is paused because Key cannot choose between them safely.” Inspection confirmed that the current read path refuses competing heads, while the mutation path can automatically merge disjoint edits. `conflict list --json` returned an empty list, and the next planned save successfully merged the histories. The read boundary was observed as implemented; the claim that saving is paused is misleading in this case. The subsequent wording fix replaces that claim with “The latest vault changes need to be combined before Key can use them” and retains the explicit stale-read warning. Read and mutation checks, error category and exit code are unchanged. The focused `VaultUXCLITests` and `V3RecoveryVaultRuntimeTests` run passed all 26 tests; file-scoped formatting and correctness checks passed. This source-only change is not present in the already installed Preview27/Air30 artifacts used for the subsequent lifecycle tests. No product code was changed during the earlier concurrent-edit qualification. Evidence is in `.build/piv-two-mac-conflicts-20261103/premerge-read-observation.json`, alongside the runtime and mutation paths cited there.

## Air removal and rejoin, 2026-11-03

The owner authorized removing and rejoining the Air in the same disposable vault and qualification app, preserving Stable and both keys. Both Macs first matched the final conflict-resolution head `150f76b75003058e9b2e2adce63b1d75132dbae1f5664d062ab43aba91223e3a`, all 60 published files and their existing app/configuration/checkpoint baselines. The Mini's preceding wording-only source change passed 26 focused tests plus formatting and correctness checks; the installed Mini Preview27 and Air build30 retained their earlier wording and unchanged lifecycle implementation.

The Mini's native review identified only `MacBook Air lifecycle test`, device `bL5KxnrX7YklHeQSFBQ7m073oBNg76cWlmC3ahxYS0o`, for removal by `Tim’s Mac mini`. After the authorized `REVOKE` confirmation, the command succeeded. Manifest `38edd0ae5e7f70c210f24453673c3a1c4725aae3c3e4141b2431cedbda9d3da7` changed the encryption key and authority transition, reencrypted all nine entries, retained the old Air identity as revoked and removed its device wrapper. The Mini remained active; both recovery recipient descriptors and their generation were unchanged, with new recovery wrappers for the new vault key. No hardware operation was needed.

The Mini added `lifecycle/after-air-removal` after removal and verified all previous values and TOTP. Head `6285ec9342e0e4b46819fae360561a6ceee55e352f3bf19ed38ec75b4ed4830d` contains 72 published files and ten current entries, with ready status and no conflicts or pending work. The Air checked a pinned complete inventory received through iCloud before locking its helper and attempting one ordinary read of the new entry. It refused with exit6, no plaintext output, and the explicit message that this Mac's access had been removed. The old Air checkpoint, configuration and protected apps/support records remained unchanged. No stale read or retry was used to obtain this result.

This passes removal and refusal of current data for the tested artifacts. Rejoin continues through a fresh invitation and the native reviewed replacement flow in the same configured Air app. Mini evidence is retained under `.build/piv-two-mac-rejoin-20261103/`, including `revocation-review-and-result.txt`, `revocation-authority-checks.json`, `revoked-with-new-entry.json` and `air-denial-summary.json`; the Air retains `q2-air-revocation-denial-20261103.json`. Older acquired values and historical copies remain outside the effect of revocation by design.

### Reviewed replacement and reenrollment

A fresh ten-minute invitation was created only after the Air's denial check and rejoin preparation completed. In the same configured build30 app, the native interactive review named the original vault and revoked Air identity. One authorized `REJOIN` confirmation removed that old local device state through the supported workflow and created fresh credentials. No new namespace, manual credential/checkpoint deletion or vault initialization was used. The original configuration and published vault files were preserved while the new request was prepared.

Both Macs independently matched comparison code `1b63-55d8-17e5-9f03-75ad`, exact Mac names, vault/request identities and the signed invitation/request file hashes. The new Air device is `w6b3UgTY4q5Tgn4UKC5WGaST9lTRBti1YzK46iGH9wY`; its signing and wrapping public keys both differ from the old identity. The Mini approved that comparison, then the Air accepted exactly once. Head `fbd702870cf06de7aa52f442fa81ff31a8bd1d7930fe981c3fe8a8b2a49fdc23` contains 83 published files and ten current entries, with the Mini and new Air active and the old Air retained as revoked. Device key wrappers address only the two active identities. Enrollment created a fresh key epoch and reencrypted the ten entries while preserving both recovery recipient descriptors and their generation.

The Air's authenticated device inventory confirmed the new local identity. All nine exact secret hashes matched, including the post-removal entry previously denied; TOTP also passed independent Mini verification against the retained fixture seed and exact read interval. Both Macs reported ready status and no conflicts or pending recovery work. This demonstrates current access through replacement credentials while the old identity remains revoked. Mini evidence includes `rejoin-comparison.json`, `rejoin-authority-checks.json`, `rejoin-approved.json` and `air-rejoined-summary.json`; the Air retains `q2-air-rejoin-acceptance-20261103.json` and its native review/verification records.

### Post-rejoin delivery and reopening

The Mini added `lifecycle/rejoined-mini`; the Air verified all 78 bytes, including the final newline, through the shared iCloud folder. The Air then added `lifecycle/rejoined-air` exactly once and verified all 95 bytes. The Mini matched the Air's complete 87-file inventory and read its new value exactly. The resulting common head is `5c41f89f6e8d773353485753f903418e1e8f57bb6970813d3e6bd62011c4a47a`, with 31 manifests, 56 encrypted entry versions and twelve current entries. All previously published files remain intact.

The Mini verified all eleven secret values and TOTP before and after a fresh-helper reopen. Both checks reported ready status, no conflicts and no pending recovery work. The old Air identity remains revoked; the Mini and replacement Air are active, and both original recovery recipient descriptors and their generation remain unchanged. All 332 Stable checks, both Q1 restored vaults, the frozen Q1 source and the Mini configuration remained unchanged. The Mini's test helper finished locked and stopped. Evidence includes `post-rejoin-mini-verified.json`, `post-rejoin-air-summary.json`, `final-ordinary.json`, `final-reopened.json` and `mini-final-preservation.json` in the rejoin evidence directory.

The Air then matched all eleven exact secret values before and after its own fresh-helper reopen, with twelve entries, ready status, no conflicts and no pending recovery work. The Mini independently verified the Air's final six-byte TOTP fingerprint against the retained seed and reported read interval. The Air confirmed the same full 87-file inventory and final head, unchanged configuration and protected apps/support, and a stopped helper after final lock. Its old identity remained revoked and excluded from device wrappers. The chat's temporary model-capacity interruption was resumed from saved command receipts without repeating the Air's add or any enrollment mutation.

Removal, denial of new current data, reviewed same-app credential replacement, rejoining, bidirectional delivery and fresh-helper reopening now pass for these private artifacts. Both test apps are locked on the original shared source; Stable and both keys' existing setup were untouched. The final local records are `air-final-summary.json` and `session-result.json` alongside the Mini evidence above. Q2 still requires recovery of this final history with an existing active key into a fresh unconfigured destination. Recovery-key removal, recovered-vault re-registration and final shipping-artifact qualification remain separate. No push or release occurred.

## Recovery after the two-Mac lifecycle, 2026-11-03

The owner authorized recovery of the final test history with an existing key while preserving Stable and both keys' setup. The Mini copied only the 87 published encrypted objects from final head `5c41f89f6e8d773353485753f903418e1e8f57bb6970813d3e6bd62011c4a47a` into a separate local source snapshot. Every file hash and the sole graph head matched the completed two-Mac session: 31 manifests, 56 encrypted entry versions and twelve current entries. The shared source remained unchanged.

A fresh PreviewDebug build31 from `4506bd1` was built and installed only as `/Applications/Key Preview Migration Qualification q2-recovery-1103.app`. It uses namespace `q2-recovery-1103`, with isolated support, Keychain records and helper services. Normal signatures, DER-backed entitlements, smartcard access, the helper's profile/certificate and this Mac's provisioning identifier passed verification. Full built/installed bundle hashes matched. The app refused ordinary status while unconfigured, with an empty support directory and absent destination. The preparation harness initially checked the hardware UUID instead of the provisioning UDID; correcting that public identifier check required no rebuild or signing change. The configured-vault pending command was also correctly refused before setup. This candidate includes the wording fix; its recovery implementation is unchanged from the earlier lifecycle artifacts.

With only the backup key connected, public inspection matched its existing credential, certificate, anchor and reported policies. Public native review followed the original backup registration to the exact latest twelve-entry snapshot. One owner-ready restore passed native PIN/touch and saved a complete preparation, then reached the recovery request deadline during final Mac verification after 90.064 seconds. The owner believed every visible prompt had been approved but was multitasking; a missed prompt, cancellation or precise timing cause was not established. No automatic retry was made.

The saved operation is `d87d8bab-e246-471b-9fc6-124cdd705e2f`, with new destination vault `046ae738-ddc3-46b7-a7fc-0073036aded6`. Inspection found the selected configuration, checkpoint, complete preparation and twelve-entry reservation intact. The isolated helper was locked and stopped. All 332 Stable checks, nine protected app/support/fixture roots, the shared source and its encrypted snapshot matched their baselines. At this checkpoint, explicit resume of the same saved attempt was still required; the successful continuation follows below. Local evidence is retained in `.build/piv-final-history-20261103/`, including artifact checks, the source baseline, public key/review records, `restore-result.json`, `timeout-state.json`, `saved-attempt-before-resume.json` and `preservation-result.json`.

### Exact resume and recovered-value verification

After renewed readiness to watch every prompt, one explicit resume with the original source, destination, token and recipient succeeded in 33.713 seconds. It completed the same operation and destination vault. The saved preparation, reservation, selected configuration, checkpoint and all published destination bytes were unchanged across resume. No replacement restore, new registration or hardware write was performed. Public backup-key inspection afterward matched its pre-restore credential, certificate, anchor, reported policies and retry metadata exactly. The first key remained disconnected.

With both keys disconnected, all eleven exact secret values matched the final two-Mac snapshot, including the chosen conflict value and entries created after removal and rejoin. The authenticator output matched the retained seed over the measured read interval. These checks passed again after lock and a confirmed fresh helper process. Both reads reported ready status, twelve entries, no conflicts and no pending recovery work. The destination has fresh vault/device/signing/wrapping identities and no inherited recovery registration; its final head is `1b98c3ded7bc82387217889ec5bad2b298d649212a282f40ad9f465d309771d6`.

All 332 Stable checks and nine protected app/support/fixture inventories remained unchanged. The original shared source and frozen 87-file snapshot remained byte-identical. The new destination helper finished locked and stopped. Final evidence includes `resume-result.json`, `resume-identity-verification.json`, `key-after.json`, `ordinary-verification.json`, `reopened-verification.json`, `reopen-pids.json`, `preservation-result.json` and `session-result.json` in the final-history evidence directory.

Q2 is passed at this recorded scope: one unchanged active key recovered the exact final history after two-Mac enrollment, concurrent edits, conflict resolution, removal, rejoin and later edits. The timeout's precise prompt/timing cause remains unestablished; successful exact resume qualifies that observed interruption, not every Q5 failure phase. This private build31 result does not replace final shipping-artifact qualification. Q3 recipient removal, Q4 new registration/second recovery and the remaining interruption/platform/release gates remain open. No product code change, push or release occurred in this recovery session.

## Recovery-key removal preparation, 2026-11-03

The owner authorized reviewing removal coverage and preparing a disposable live test while preserving Stable and both keys' setup. The inspected CLI, routing, removal workflow, planner, builder/validator and publisher separate exact reviewed consent from publication. Removal changes the encryption key and recovery generation, reencrypts the current entries, marks only the chosen recipient revoked and omits its new wrapper. It preserves the device roster and does not administer the hardware key. Last-recipient removal requires the distinct `REMOVE LAST RECOVERY KEY` phrase; plain `REMOVE` cancels without an execution request.

All 54 focused tests across five suites passed on `f14b673`: recipient policy, durable publication, product workflow, CLI and request routing. Coverage includes one/last removal, unchanged plaintext and other authorities, old-key failure on new ciphertext, remaining-recipient recovery after later edits, exact confirmation and stale-plan refusal, noninteractive refusal, cancellation, cleanup and pinned restart across fourteen publication boundaries. Software coverage also proves removed-recipient selection fails before agreement. No production gap requiring a change was found in this scoped review. These software results do not replace the signed native checks below.

The original twelve-entry source at `5c41f89f6e8d773353485753f903418e1e8f57bb6970813d3e6bd62011c4a47a` was preserved as a labelled 87-file snapshot before any removal. The proposed live sequence continues only the existing disposable shared vault: remove original recipient `cxRS8dxO8OSY_hQqIh-bplLsch8K6BFWTuzcmgH3Qs4`, add a synthetic entry, verify refusal for that recipient and recover with backup recipient `MI2m8GPlaZk-Fm6-BS5f5fIHxqFGl74sZVKyj9JrkaY`. Later last-recipient removal gets a separate owner review, with another retained snapshot. Older copies remain recoverable with their old keys; they are not evidence of current recovery after removal. The Air was told to remain locked without reading or editing during this Mini-side test.

A fresh PreviewDebug build32 from `f14b673` was installed only as `/Applications/Key Preview Migration Qualification q3-remaining-1103.app`, with isolated namespace, support and helper services. Signature, entitlement, profile/certificate/device and complete bundle-hash checks passed. It has no configured vault and is reserved for the remaining-key recovery. Baselines retain 332 Stable checks and twelve protected app/support/fixture roots, plus the owner Preview configuration. Neither key was contacted or changed during preparation. Evidence is in `.build/piv-recipient-removal-20261103/`, including `focused-tests.log`, `baseline.json`, `before-removal/`, the preservation baselines and build32 records. This preparation checkpoint alone is not a Q3 pass.

### Original-key removal and remaining-key recovery

With both keys disconnected and owner readiness for normal Mac approval, the Mini verified the original twelve entries, both registrations and exact source head. The native review named only original recipient `cxRS8dxO8OSY_hQqIh-bplLsch8K6BFWTuzcmgH3Qs4` and one remaining active key. After `REMOVE`, publication succeeded at `d42632787d613443fed49e5a116e2939f7518cd6808ff3c8e74e8bcf35d01108`, with cleanup pending false. The encryption key and recovery generation changed, all twelve entries were preserved, the device roster was unchanged, and only the backup recipient retained a recovery wrapper. A later synthetic entry produced thirteen current entries at `c8a1eba571ab4b5e28806b967a67f583ea60cf52ebab4646d586cde6e5b64370`. The complete 102-file continuation was frozen in `one-recipient-source/`.

The original key's public before/after inspection matched its retained Q1 credential, certificate, anchor, policies and retry metadata. The unconfigured build32 app recognized that same credential and successfully reviewed the retained twelve-entry source, then refused review of the updated continuation with exit 1 and no output data. No PIN, touch, agreement, configuration or destination creation was requested. Manifest inspection and the software history-selector coverage establish the removal boundary; this public review did not decrypt either snapshot.

The unchanged backup key selected the exact thirteen-entry continuation through its original registration anchor. One native restore saved a complete preparation but reached the recovery request deadline during final Mac verification after 91.237 seconds. The owner initially believed all prompts were approved, then clarified uncertainty. After explicitly renewed readiness, one exact resume succeeded in 35.599 seconds, completing operation `a8384290-0edd-4b9c-b96f-e077503c3122` and destination vault `abf321e2-dbc8-4bb2-b6de-80755b247f40`. Configuration, checkpoint, preparation, reservation and published destination bytes matched the saved attempt. The backup key's public setup remained unchanged.

With both keys absent, all twelve exact secret values and the current authenticator code passed before and after fresh-helper reopening. Status was ready with thirteen entries and no conflicts or pending work. The restored vault has fresh Mac authority and no inherited recovery registration; its final head is `26895756a5699d564fd1227b0aece25b947aaf19b0e138e9d6e581b00c4a0a88`. The destination finished locked. All 332 Stable checks and twelve protected app/support/fixture inventories matched, and both retained source snapshots remained unchanged. Evidence includes `original-removed.json`, `one-recipient-current.json`, `original-refusal-summary.json`, both keys' public records, restore/resume records, both recovered-value checks and `preservation-result.json`.

### Removed-key wording and repeated deadline findings

Native public review exposed `KeyCore.V3RecoveryValidationError error 10` when the original key was correctly refused. The shared host response boundary now translates that specific removed-recipient error to: “This recovery key was removed from this version of the vault. Check recovery registration status on a Mac that still has access.” The refusal and exit status are unchanged. CLI review and restore/resume regression tests reproduced the internal-error message before the fix; afterward all 47 focused review, recovery-routing, removal-CLI and removal-routing tests passed. Formatting, strict lint and whitespace checks also passed. The installed private artifacts retain the earlier wording; final candidate qualification must include this source fix.

The two latest initial restores timed out after 90.064 and 91.237 seconds, while their explicit resumes succeeded in 33.713 and 35.599 seconds. `KeyRecoveryRequest.maximumDurationSeconds` is 90 and the host applies that deadline to the whole request, including its authentication stages. The observed message is the request-deadline refusal, not evidence that the separate 120-second client reply timer expired. The prompt history remains uncertain. Review the initial restore's authentication cost and deadline behavior before release; these results do not establish a provider hang, user cancellation or a safe timeout adjustment. No timeout or authentication policy was changed in this test session.

### Last-key removal and continued Mac access

After a separate owner authorization, both keys remained disconnected while the Mini reviewed removal of backup recipient `MI2m8GPlaZk-Fm6-BS5f5fIHxqFGl74sZVKyj9JrkaY`. The native review reported zero other keys and warned that recovery would be unavailable. Entering plain `REMOVE` returned exit 1 with “No removal request was sent.” The source's complete published inventory and checkpoint stayed unchanged, with no pending operation. A fresh review of that same state received the authorized `REMOVE LAST RECOVERY KEY` phrase and normal Mac approval, then completed with cleanup pending false.

The removal published head `d02d04e41d9617f149f8702b37632b438eacaf639829fd4b21bc6fe131e966b7`, a fresh encryption key and recovery generation, both recipient records revoked and no recovery wrappers. All thirteen values were preserved and the Mac roster was unchanged. A later synthetic entry produced the final head `a753e067ee2cfddf97b81dd73825639ad599847a0754ace45548e1627a90270d`: 35 manifests, 83 encrypted entry versions and fourteen current entries. All thirteen exact secrets and TOTP passed again after fresh-helper reopening with both keys absent. The owner Preview finished locked and stopped.

With only the backup key connected, public review still recognized the retained one-key snapshot but refused the final no-key snapshot with exit 1 and no output data. No PIN or touch was requested. The backup key's credential, certificate, anchor, policies and retry metadata still matched its before record. The original key remained disconnected after its earlier unchanged-state check. Both labelled earlier snapshots and the complete no-key snapshot are retained; no older object was removed from the continuing source. The recovered thirteen-entry vault also remained unchanged and locked. The final preservation audit again passed all 332 Stable checks and twelve protected roots.

Q3 is passed for the recorded Preview27 owner and build32 recovery artifacts. The evidence proves continuing remaining-key recovery after one removal, informed last-key removal, loss of recovery wrappers on the continuing history, and continued Mac access after later edits. It does not claim revocation of older copies or a private-key operation during the public refusal checks. Final records include `last-removal-decline-result.json`, `remove-last.log`, `no-recipient-reopened.json`, `backup-final-refusal-summary.json`, `key-after-last-review.json`, `preservation-result.json` and `session-result.json`. The Air was left locked with its earlier Q2 checkpoint; its cached two-key roster is not the current continuing state. No push or release occurred.

## Artifact identity and tested environment

Tested: Mini and MacBook Air, arm64 macOS 27.0.1 (26A434), one YubiKey 5C NFC,
firmware 5.8.0, externally generated P-256 slot 9d credential with reported
PIN/touch ALWAYS. This is not a frozen macOS 26+/token support matrix or an
independent-backup-key test.

The artifacts are normal isolated Preview products, version 0.2.0, with local
experimental recovery enabled before signing. Shipping gates remain disabled.
Developer ID/team `9Q355KSV85`, normal Preview IDs, hardened runtime, strict/
all-slice signatures, helper smartcard entitlement, notarization, ticket,
Gatekeeper and channel isolation passed the recorded install checks. These
are installed test candidates, not published semver releases.

| Build | Exact source commit | Notarized transfer ZIP SHA-256 |
|---|---|---|
| 22 | `ea1f8f546fd36a078db16790a2bc2976a98abaa6` | `3f6527a01883f1ea7dc0904e07b0d635592df8c4b18ee47f0622cef9332d8ca4` |
| 23 | `9f9872f4a04be5b878b2b90dbc8e16e94bd77276` | `e600810430a4a1ce9855496154893a261d43456e37670c40c56cf40a9fe97edb` |
| 24 | `8fa8b0ddd24affafc66e8d7643414a5f0f0ec9f3` | `14170fc3df0cf241235d5896970818f8e72da8c478ffc1de80e01b1d177b9587` |
| 25 | `85ee569b0487dfcf78fa4e186295c8c63f394fcc` | `787d0259ddf133e4dd9788dcba5206df997797d7ccb1935502c2c3c73932b1aa` |

Build25 notarization: Accepted, submission
`f28c0b5e-9dac-46ab-926b-b13316e5cf99`; detailed receipt inspected, no issues.
Installed executable SHA-256:

| Component | Hash |
|---|---|
| Host | `fc32db086dfc390dcb549455b419962fcff91d18f60fa4d4a1c86eaac855ad0d` |
| CLI | `110fcc0d7c571c548dd19cf82488eaa1204c160429d83ced7b2777316c2e3b02` |
| Helper | `d8c80fa139e798869693bb3382c178f12c81a27feecc750b45f74509ded766dc` |

Older candidate receipts/component hashes remain in their ignored preparation/
install records and Git history. A result on an older build is scoped evidence,
not an automatic retest pass on build25. Recheck affected cases if later code changes.

## Completed signed cases

All rows below are real installed-product cases. Software-only evidence is
identified separately in the plan and linked test suites. App token administration
was never used; credential setup/import were separately owner-run external steps.
PINs stayed in macOS UI. Stable app/config, explicit prior disposable state and
source-preservation checks stayed within named roots; actual-vault contents were
not traversed. Prompt counts are owner observations, not native hardware-attempt
measurements. Evidence IDs resolve in the local index below.

| Case | Artifact/machine | Observed result and scope | Evidence |
|---|---|---|---|
| Protected setup/public binding | Mini, before22 | Owner configured management protection and generated compatible credential/certificate, then externally imported the reviewed anchor. Public key/anchor/policy readback matched. Metadata does not attest key provenance or secret custody. | E01 |
| Registration finish | 22 Mini | One PIN/touch activated the exact prepared candidate; no pending operation; entries-before-manifest/checkpoint result and expected file delta verified. Public postcheck unchanged, PIN/PUK 3/3. | E02 |
| Initial source-only restore | 22 Mini/Air | Published encrypted files plus key restored two entries with fresh authority and no inherited registration. Air exit0/18.837s. No Mini credentials/config/checkpoints/intent transferred. | E03/E04 |
| Ordinary token-free access | 22 Mini/Air | Exact secret including newline and independent seed/read-interval TOTP checks passed before/after normal lock/fresh helper; token absent, sources/Stable preserved. Guided Air pass does not explain its earlier health timeout. | E03/E04 |
| PIN cancellation | 22 Mini | Owner cancelled without entering PIN/touch; exit1/1.216s, no agreement/destination/config/new saved attempt; normal shutdown and unchanged public state/counters. | E05 |
| Visible touch-window Cancel | 23 Mini | Owner approved PIN, saw the foreground touch window and clicked Cancel without touching. No publication. Native exchange returned 10.238 seconds after logical cancellation, before card postchecks; this does not qualify immediate native abortion. Old22 invisible-window attempt is not a cancellation pass. | E06 |
| Incomplete reservation release | 24 Mini | Explicit exact `recovery abandon` released only reservation ownership without authentication/key operation. Empty target, reservation file and Mac credentials retained; no replacement restore. | E07 |
| Complete-preparation Publish cancellation | 24 Mini | Owner approved Prepare and cancelled Publish. Exit1/22.801s; complete reservation/preparation retained, target empty/config absent. Wrong-stage earlier attempts do not qualify this case. | E08 |
| Exact resume and token-free reopen | 24 Mini | Explicit resume through fresh helper used the same operation/vault/key/device/entry IDs and byte-identical preparation/published objects. Owner observed one PIN/touch then five Mac approvals. Later exact secret/TOTP and token-free fresh-helper reads passed. | E08/E09 |
| Missing touch | 24 Mini | One approved PIN, no touch/Cancel; window closed without Mac prompt. Exit1/23.231s, no destination/config/saved-file changes. This is provider failure-path evidence, not the 90-second application deadline. | E10 |
| Physical token removal | 24 Mini | Unplug at touch window after PIN, no touch/Cancel; window closed/no Mac prompt. Exit1/8.315s, no publication/state change; normal shutdown and public-only postcheck after reconnect matched, PIN/PUK 3/3. | E11 |
| Unanswered-PIN deadline | 25 Mini | Explicit timeout around 90 seconds, actual appCancel callback and no publication/state change. System PIN UI remained; owner manually cancelled blank dialog before normal shutdown/postcheck. Deadline/refusal pass; automatic UI cleanup fails. | E12 |
| Late PIN after confirmed timeout | 25 Mini | After 90.029 seconds timeout and passive refusal checks, owner submitted correct PIN once without touch/Mac approval. Dialog closed with no follow-on Key prompt; destination/config absent and protected files unchanged. No native late-positive callback was exercised. | E13 |
| Owned CLI disconnect | 25 Mini | Only verified owned CLI got SIGTERM at 47.051 seconds, before deadline. Helper invalidated context/received appCancel; no touch stage/publication. Owner cancelled blank PIN; normal shutdown/public postcheck passed. No helper/provider signal or retry. | E14 |
| Edits/rotation/later edits recovered | 25 Mini | Token unplugged for secret/TOTP re-save, one key rotation and postrotation add/edit. Recovery of ten manifests/three current entries passed in 29.501 seconds with one PIN/touch. Exact values and token-free fresh-helper reads passed. Recipient/generation retained; key/epoch/wrappers changed. | E15 |
| Independent edited/rotated-history recovery | 25 Air | Same published ten-manifest/twelve-entry-version copy, no source authority/local records; one PIN/touch restored three entries in 42.430 seconds. Both secrets matched twice; health ready/no conflicts/pending work; token absent before/after; new authority/no inherited registration, final helper stopped. | E16 |
| Independent TOTP comparison for Air25 | Mini, offline verifier | Both ordinary/fresh-helper fingerprints matched retained seed and actual read intervals; public vectors passed. Each interval had one matching candidate counter. No seed/code transferred or printed. TOTP edit reused original seed: continuity qualified, seed replacement not tested. | E16 |

## Known limits

- **Remaining system PIN dialog.** Programmatic invalidation can deliver actual
  appCancel while macOS PIV UI stays visible. Retained-context, main-thread,
  released-handle, fresh-context and direct-operation controls did not establish
  automatic dismissal. Ordinary Mac policy/ACL controls dismissed correctly;
  that narrows the investigation, not a proven OS/provider defect. Owner accepted
  manual Cancel for Preview on 2026-10-26. Cancel blank leftover UI before further
  card use; late PIN entry may still affect device authentication/retry counters.
  A stopped Key request cannot revive. No private API, provider termination or
  direct-operation production workaround is selected.
- **Callback scope.** Late-PIN/disconnect native results cover the observed paths.
  They did not exercise a native late-positive callback race or measure all
  framework attempts. [Software regressions](../Tests/KeyCoreTests/PIVRecoveryAgreementTests.swift)
  cover late/duplicate approval and retained exclusion until actual callback/
  provider return. Callback receipt and helper exit do not prove UI closure.
- **Mac approval cost.** Exact resume observed five Mac approvals after PIN/touch.
  These protect separate destination wrapper/trust/activation boundaries; no
  fixed count or prompt consolidation is promised.
- **Coverage.** One physical credential, two arm64 Macs/one OS build; no independent
  backup-token, full device/recipient lifecycle, complete provider/platform matrix
  or released-old-binary adoption qualification. Restored vaults remain
  unregistered until separately protected.
- **Preservation claims.** Checks cover explicit sources, destinations, prior test
  roots, apps/configs and relevant records. They are not a whole-Keychain/system
  integrity claim; restore intentionally creates new destination credentials.
  Mini PIN/PUK 3/3 observations apply to the recorded postchecks, not an unperformed
  Air25 counter query.

## Consequential failures and disposition

| Finding | Disposition / what remains unproven |
|---|---|
| Early public reads failed | Preview smartcard entitlement and bounded response framing were corrected and regression-tested. Later signed public/product runs qualify their scoped fixes; diagnostic-only binaries are not product qualification. |
| Build22 touch cue could be obscured | AppKit ordering diagnostics plus owner observation led to visible native presentation in23. The earlier no-touch failure did not qualify clicking Cancel. |
| Cancellation hit an earlier Mac stage | Clear Prepare/Publish reasons and incomplete-attempt handling shipped in24. Only the owner-confirmed complete-preparation cancellation/exact resume is counted. |
| Authentication worker released before real callback | Source fix `87e311d` retains worker/lease until actual framework reply;25 records callback lifetime and refusal. It did not solve external PIN-window dismissal. |
| Earlier Air22 health timeout | Owner was not watching; cause and old prompt completion were unconfirmed. Later guided explicit-unlock/read/fresh-helper success is separate evidence, not retrospective cancellation proof. |
| Air25 public JSON/USB guards | Successful inventory output was parsed without repeating inventory. Sandboxed registry read failed before restore; identical elevated read-only check succeeded after coordinating diagnosis. Exactly one restore was dispatched. |

## Local evidence index

Paths below are relative to ignored `tmp/piv-recovery/` on Mini unless marked Air.
They identify maintainer evidence, not files a recovering user must retain or a
claim that raw reports are in Git. Preserve old results and supersede them with
new scoped results rather than rewriting failures as passes.

| ID | Retained root / principal record |
|---|---|
| E01 | `fresh-credential-2026-10-23/`, `anchor-import-verified-2026-10-23/`, `registration-mini-2026-10-23/`; owner setup/public credential/import verification. |
| E02 | `product-touch-build22-finish-2026-10-25/postcheck-result.json`. |
| E03 | `product-touch-build22-restore-2026-10-25/verification-result.json`; source and ordinary/fresh-helper exact-value evidence. |
| E04 | `build22-air-transfer-2026-10-25/`; retrieved restore/ordinary summaries, owner observations and `air-totp-verification.json`. |
| E05 | `cancellation-resume-mini-2026-10-25/`; successful PIN-cancel record separated from accidental positive restore and failed touch-window case. |
| E06 | `cancellation-resume-mini-2026-10-25/touch-cancel-build23/`; later wrong-stage case in sibling `saved-preparation/`. |
| E07 | `approval-incomplete-build24-release-2026-10-25/`. |
| E08 | `approval-incomplete-build24-resume-retest-2026-10-25/`; exact saved/prepared/published bytes and resume result; earlier `approval-incomplete-build24-resume-2026-10-25/` preserved separately. |
| E09 | `build24-resumed-ordinary-2026-10-26/verification-result.json`. |
| E10 | `build24-touch-timeout-2026-10-26/`. |
| E11 | `build24-disconnect-2026-10-26/`. |
| E12 | `build25-deadline-2026-10-26/`; isolated controls under `pin-cancellation-*-2026-10-26/`. |
| E13 | `build25-late-pin-2026-10-26/verification-result.json`. |
| E14 | `build25-cli-disconnect-2026-10-26/verification-result.json`. |
| E15 | `build25-edits-rotation-2026-10-26/verification-result.json`. |
| E16 | `build25-air-edited-history-2026-10-26/`: packet identity, owner confirmations, Air restore/ordinary summaries, `air-totp-verification.json` and combined `verification-result.json`. |

Air25 full native records remain under
`~/.codex/visualizations/2026/10/02/01a0fe8a-6281-7272-999d-899cf6cec486/piv-air-test/`:
`air-product-build25-preparation.json`, `air-product-build25-public-preflight.json`,
`air-product-build25-restore-attempt.json` and
`air-product-build25-ordinary-access.json`. The receipt is
`~/Downloads/Key-Preview-build25-Air-20261026T183412Z-receipt/`, including rollback,
previous selection/cache, encrypted source and the new disposable restored vault.
No extra Air operation is needed merely to update this ledger.

Artifact preparation/install roots include
`product-touch-build22-2026-10-25/`, `product-touch-build23-2026-10-25/`,
`approval-incomplete-build24-2026-10-25/` and
`native-authentication-build25-2026-10-26/`, plus their named install siblings.
Checksummed verbatim pre-consolidation documents are in
`docs-consolidation-2026-10-26/`; complete tracked chronology also remains at
commit `dd2c64f70d0b72cfd75da310326a883b10b34d0f` and earlier history.

## Remaining native work and run discipline

The [plan's acceptance matrix](piv-recovery-plan.md#remaining-acceptance-matrix)
is authoritative: independent backup token, broader device/recipient product
flows, branch/conflict recovery, interrupted setup/rotation/helper cases,
restored-vault mutation/re-registration/second recovery, credential lifecycle,
compatibility/provider and release/adoption gates remain. Reuse the passes above;
no repeat of the basic two-Mac restore without changed code or an unresolved issue.

For each newly authorized case:

1. Pin source/build/OS/hardware identity and expected outcome; choose explicit
   disposable roots and preserve relevant config/cache, journals and prior vaults.
   Obtain exact-scope approval for installations, state relocation or hardware
   administration. Never reset shared state to force progress.
2. Use matching signed CLI/helper, normal trust checks and normal lifecycle.
   Refuse uncertain pending ownership and pre-existing/aliased restore targets.
   Public review/pending selectors are observations, not readiness/consent.
3. Obtain fresh owner connection/watch readiness before a private operation.
   PIN stays in macOS; physical touch is distinct from clicking OK. Mac approvals
   are separate. Never ask for credential values or deliberately consume retries.
4. Dispatch one guarded request. On timeout/failure/lost reply preserve exact
   source/destination/intent/credentials/config; do not retry, generate replacement
   setup or infer success from files. Inspect and explicitly resume the exact
   prepared attempt, or use narrowly qualified abandonment when applicable.
5. Confirm UI closure and actual callback/provider lifetime before further card
   use/postchecks; manually cancel blank stale PIN UI when necessary. Never
   force-stop a helper/provider to manufacture a clean result.
6. Verify complete authoritative reply, source/new-authority/preservation checks,
   expected current contents and token-free ordinary access as appropriate.
   Normal lock already stops the helper; verify before fresh-helper reads.
   Keep plaintext in memory, use exact-byte secret comparison and independent
   TOTP seed/read-interval comparison. End normally locked/stopped.

Retain raw commands, hashes, observations, ambiguity and failures locally. Commit
one concise completed-case update with its limits/evidence reference, not a new
narrative for each preparation, signing, installation or diagnostic transition.
