# Two-Mac recovery lifecycle session

Prepared on 2026-11-03 after independent recovery with both keys and ordinary editing/reopening of a recovered vault passed. This is the concrete Q2 session in the [qualification runbook](piv-recovery-qualification.md). Preparation does not count as enrollment or lifecycle qualification. Keep the work on `codex/prepare-0.3.0` in local commits without pushing.

Current preparation status: ready for the live session. After the owner refreshed Xcode sign-in, the Air's normal build30 retry passed in 32.02 seconds. The signed artifact was verified and installed only at the fresh qualification path. Its helper registered, status refused with “No vault is configured,” configuration remained absent, and the helper was stopped through its own lock command. Existing apps, support records, helper states and source files remained unchanged. The original provisioning failure and verifier-command correction remain recorded; neither required a product change or signing bypass. No invitation, enrollment, vault authentication or hardware operation has begun.

## Apps and protected state

The Mini uses its existing private notarized Preview27 at `/Applications/Key Preview.app`, with bundled CLI `/Applications/Key Preview.app/Contents/MacOS/key-preview`. Its source was `661c69e`; the preparation packet at `8f4c2b5` has identical application/configuration source. The installed Air candidate uses that packet, PreviewDebug, namespace `q2-lifecycle-air-1103` and private build30, built with the current qualification script. Actual signatures, DER entitlements, profile/device membership, namespace/service constraints and full bundle hashes passed verification before installation. Recheck the recorded installed hashes before the live session. Do not use the Air's older checkout/build script.

The Air's installed test app path is `/Applications/Key Preview Migration Qualification q2-lifecycle-air-1103.app`. Its app/helper identifiers, service, support and Keychain service/account carry that namespace; the Preview CLI signing identifier and Keychain access group remain shared with other Preview qualification apps. The Air's existing Stable, Preview25 and `release030-twomac-1030` qualification app and fixtures must remain unchanged. Rejoining must use the same Q2 app and configuration, not a second fresh namespace.

The original disposable source is vault `8b67cabc-7c4a-4eae-a67e-edc06cf47ea4`, at `~/Library/Mobile Documents/com~apple~CloudDocs/Key Preview Vault/recovery-qualification-2026-11-03/vault`. Preparation baseline: head `GPFsg_TJzAa-64IEPydtJO_FSGwykfn5niWWfeZICsI`, 16 published manifests, 22 encrypted entry versions, four current entries and both active recovery recipients. Its sole current device is `EuGOQOhg9vj7bwqa1efmJ2vjnE4BEJyTrE2j_zJgO6A`, displayed as `Tim’s Mac mini`. Revalidate these against current files and authenticated status when the live session starts.

Both physical keys stay disconnected throughout enrollment, edits, revocation and rejoin. The later recovery check uses an existing unchanged anchor with announced PIN/touch readiness. No credential, certificate, anchor, PIN, PUK or management-key changes belong to Q2. Preserve the source baseline and both Q1 restored destinations. The separate source/build transfer packet lives under iCloud Drive `Key Preview Vault/lifecycle-preparation-2026-11-03`; it contains tracked code and a build recipe, not source-Mac credentials or test secret values.

## Before opening prompts

Record the installed app hashes, configuration bytes, published file inventories and helper registrations on both Macs. Verify the new Air namespace has no selected vault or retained attempt. Wait for the complete source inventory to match on both hosts; do not initialize the source folder. Verify no pending setup/rotation/replacement operation and that both recovery recipients remain active. Gather the owner's readiness for ordinary Mac approval on both machines before creating an invitation. Invitations expire after ten minutes, so none should be created during build preparation.

Use absolute bundled CLI paths throughout. In the command outlines below, `mini` means the existing Preview27 CLI and `air` means only the fresh Q2 Air app's bundled `key-preview`. IDs and comparison codes are captured from that live attempt, never reused from an older fixture. Capture secret outputs in memory for exact comparisons; retain hashes and TOTP read intervals rather than plaintext or codes.

## Enrollment and ordinary delivery

1. On the Mini, run `share devices`, then `share invite --name "Tim’s Mac mini"` using the exact confirmed current name. On the Air, run `share invitations --vault-dir <source>` and `share join <invitation-id> --name "MacBook Air lifecycle test" --vault-dir <source>`.
2. On the Mini, use `share requests <invitation-id>` and `share compare <vault-id> <invitation-id> <request-id>`. On the Air, use `share compare <vault-id> <invitation-id> --vault-dir <source>`. Compare the complete code and both device names from the two hosts before approval. Stop on any mismatch.
3. Run `share approve <vault-id> <invitation-id> <comparison-code>` on the Mini, then `share accept <vault-id> <invitation-id> <comparison-code> --vault-dir <source>` on the Air. Only acceptance should select the Air configuration. Record both public device identities and verify current values, ready status and unchanged recovery recipients.
4. Make one synthetic edit on each Mac in sequence and verify delivery through the actual shared iCloud folder to the other Mac. Preserve the exact resulting common head and value hashes before testing concurrent changes.

## Reproducible concurrent edits

Do not disable networking or pause iCloud globally, since that would affect Stable. To produce real competing writes predictably, use complete local published-file copies of the same disposable vault, one on each host. At a verified common head, lock the test apps, copy only published `manifests/` and `entries/` to fresh local working folders, verify every file hash, then use each test app's supported `config set vault-dir <local-folder>` command. This retains its vault ID and existing local Mac credentials. Record the original paths and preserve all source files. These local views are a controlled delivery test, not evidence of iCloud's conflict timing.

Start both writes from the recorded common head before delivering either new branch. Exchange only verified immutable encrypted objects and manifests, through a separate test transfer folder; never copy configuration, checkpoints, Keychain records or journals between Macs. Refuse a same-path/different-content file, unknown source vault or incomplete inventory. Preserve all prior files and record the exact two branch heads.

| Case | Actions | Required result |
|---|---|---|
| Non-overlapping writes | Mini adds `lifecycle/mini-only`; Air adds `lifecycle/air-only`. Deliver the union to both local views. Mini adds `lifecycle/merge-marker`, which exercises automatic merge before ordinary mutation. | Both original values survive. The published merge names both branch heads as parents and retains both recovery recipients. Deliver the merged continuation and verify the same values/head on Air. |
| Conflicting writes | From the next common head, both Macs edit `recovery-test/secret` to distinct synthetic values. Deliver both branches. Inspect `conflict list`, `conflict show <id>` and each version using captured output. | Ordinary current-value reading refuses the unresolved conflict. Both exact versions are available for review. Use `conflict resolve <conflict-id>=<chosen-version-id>` with a complete reviewed choice set, then verify the chosen value and a common resolved head on both Macs. |

After resolution, deliver the complete verified union back to the original iCloud test folder without replacing or deleting older immutable files. Verify delivery and use each test app's `config set vault-dir <original-source>` to return to that same lineage. Confirm the vault IDs are unchanged, both Macs read the resolved current values, and no setup/transaction is pending before changing device authority.

## Revocation and rejoin

On the Mini, `share revoke <exact-Air-device-id>` must review the intended test Air and receive the `REVOKE` confirmation. Record the authority change and both retained recovery recipients. Deliver the complete continuation to the Air, lock its helper, and verify it cannot read new current data with its revoked credentials. This is a current-history test; previously obtained values and older copies remain accessible by design.

Create a fresh invitation on the surviving Mini. In the same configured Air app, `share join <new-invitation-id> --name "MacBook Air lifecycle test"` must review replacement of the exact old Air credentials and checkpoint. Use a terminal for the `REJOIN` confirmation. Preserve any interrupted cleanup and follow the product's exact continuation; never delete state manually, run init, or switch to a fresh app to bypass replacement. Complete a new comparison/approval/acceptance ceremony. Verify a new Air device/signing/wrapping identity, the old identity recorded as revoked, successful current reads and another bidirectional edit.

## Recovery and completion

Check that both original recovery registrations remain active throughout the final history. With explicit owner readiness, use one existing key to recover the final published encrypted snapshot into a fresh unconfigured destination namespace. Verify the final values and TOTP, then lock/reopen without the key. Reuse Q1's proof that the two keys are independent; this recovery proves access survived the device lifecycle. Never re-register either key or overwrite its anchor for this check.

Retain every app/build identity, source head, public device/recipient ID, comparison result, exact-value hash, native outcome and preserved-state check. Stop after any failed or lost reply, inspect the exact saved state, and request readiness before an explicit continuation. Close only the outcomes actually observed, keep Q3 removal and Q4 re-registration separate, and lock test sessions at the end. Public shipping-identity checks, rollout decisions and publication remain later gates.
