# PIV catastrophe recovery implementation plan

Current checkpoint: 2026-11-03. The release reconciliation below separates current software evidence from signed hardware results through build 25 and later implementation changes. This file owns status and remaining acceptance. The [preparation review](#preparation-review-2026-11-03) adds a two-registration regression, isolated build recipe and concrete test runbook; it records no new hardware pass.
Later that day, the owner completed [second-key credential preparation](piv-recovery-signed-test.md#backup-key-preparation-2026-11-03) on another YubiKey 5C NFC, firmware 5.8.0. Public verification passed. Earlier references below to an uninspected second key describe the planning checkpoint, not its current state.
The subsequent [backup registration preparation](piv-recovery-signed-test.md#backup-registration-preparation-2026-11-03) resumed the original disposable vault from its verified archived files and matching retained Mac checkpoint. Private notarized Preview27 completed prepare/export, followed by owner-run anchor import and successful [registration activation](piv-recovery-signed-test.md#backup-registration-activation-2026-11-03) with native PIN and touch. Both recipients are registered with no pending setup; the first key stayed disconnected during backup registration and Stable preservation checks passed. Q1 then [passed with both physical keys independently](piv-recovery-signed-test.md#independent-recovery-with-the-original-key-2026-11-03): token-free edits/rotation/later edits, separate unconfigured destination namespaces, exact secret/TOTP checks and token-free fresh-helper reopening. The original-key attempt also passed exact resume after a missed/cancelled Mac prompt and timeout. Q2/Q3 completion is recorded below; Q4–Q7 and final release qualification remain open at their unqualified boundaries.
Q4's [ordinary recovered-vault edit/reopen](piv-recovery-signed-test.md#editing-a-recovered-vault-2026-11-03) also passed. The [two-Mac Q2 session](piv-two-mac-lifecycle-session.md) has passed compared enrollment using Mini Preview27 and isolated Air build30. Both Macs verified the original values and unchanged recovery registrations. Ordinary bidirectional iCloud delivery, controlled concurrent edits, automatic merge, explicit conflict review/resolution and fresh-helper reopening also passed. [Air removal and same-app rejoin](piv-recovery-signed-test.md#air-removal-and-rejoin-2026-11-03) also passed, including denied current access for the removed identity, compared replacement credentials, bidirectional edits and fresh-helper verification of all twelve final entries. Both test apps are locked on the original shared source with both original recovery registrations retained. [Final-history recovery](piv-recovery-signed-test.md#recovery-after-the-two-mac-lifecycle-2026-11-03) passed with the unchanged backup key in fresh Mini build31. After an initial final-verification timeout, one explicit resume completed the same saved destination; all twelve entries passed exact-value and token-free fresh-helper checks. Stable, the source, earlier fixtures and hardware setup remained unchanged, and the destination is locked. Q2 is complete for the recorded private artifacts and platform. The [premerge read wording fix](piv-recovery-signed-test.md#wording-issue-found-before-automatic-merge) is verified in source and included in build31; the earlier lifecycle artifacts retain the old wording. Q4 re-registration and second recovery still require a separate hardware-allocation plan.
Q3's [recovery-key removal](piv-recovery-signed-test.md#recovery-key-removal-preparation-2026-11-03) now passed. The unchanged backup key recovered the thirteen-entry continuation after original-recipient removal. Last-key removal rejected the ordinary confirmation, required the full protection-loss phrase, and left no recovery wrappers while later edits and token-free reopening remained usable. The continuing shared source now has fourteen entries and no active recovery recipient; labelled two-key and one-key snapshots and both physical setups are preserved. The removed-key refusal wording is fixed in source and passed its regressions. The [build33 timing diagnosis](piv-recovery-signed-test.md#initial-restore-deadline-diagnosis-2026-11-03) reproduced the 90-second initial-restore deadline despite successful hardware approval and all five Mac checks. About 69 seconds of other work followed source authentication; exact resume and token-free reopening passed. Before further release qualification, implement a suitable full-restore deadline, preserve bounded authentication/cancellation, align the client timer and profile repeated validation before optimizing it. No timeout or authentication policy has changed yet.
The [contract](piv-recovery-contract.md) owns protocol/security requirements; the
[qualification record](piv-recovery-signed-test.md) owns scoped results and artifact
identities. The v3 roadmap links here rather than maintaining another status table.

Recovery is experimental and disabled in shipping Stable/ordinary Preview
configuration. Explicitly enabled, signed Preview build25 passes the one-token,
two-Mac workflow below. This is a review checkpoint, not real-vault or release
qualification. This plan authorizes no hardware administration, authentication,
real-vault conversion, installation, publication or release.

## Completion contract

After explicit registration, either independently provisioned primary or backup
token, its PIN/touch approval and the available encrypted vault files must recover
all supported current entries on a replacement Mac. Recovery needs no source Mac
identity, checkpoint/cache, receipt, separate certificate file, setup intent,
management key or cloud escrow. Fresh destination Mac authentication is separate.
The source stays unchanged; the destination has fresh authority and no recovery
registration until separately registered.

Normal writes and supported key/device changes preserve active recovery coverage
with the tokens stored away, or refuse publication. The target is one deliberate
source hardware approval per uninterrupted recovery attempt across key epochs.
Explicit resume can require another approval. Do not weaken PIN/touch policy or
source authentication, archive historical decryption keys or silently retry.

Recovery authenticates anchored public history and all current restored contents,
without independently decrypting/revalidating every closed epoch. Ordinary
publication and catch-up retain full authentication and reseal checks. Removal
excludes recipients from fresh keys on the legitimate continuing lineage, not old
copies or hidden alternative lineages. Key refuses visible conflicts and required
missing state without falling back to older data. Provider freshness/delivery and
backup retention are external responsibilities. The
[contract](piv-recovery-contract.md#security-promise-and-limits) defines these limits;
proving global latest state is not an acceptance gate.

Full completion requires reviewed implementation, qualification with independent
primary/backup tokens on the supported platform matrix, explicit opt-in adoption,
accurate user documentation and a verified Stable release. Human expert review is
recommended; the owner selected fresh AI review as the required review gate.
Risk disclosure or a future migration cannot excuse known authentication defects
or replace missing backups.

## Current status

The implementation stack through PR #85 is merged. The current [0.3.0 release candidate](release.md#030-release-preparation) keeps recovery disabled. The owner is evaluating including PIV in 0.3.0; that would require closing the remaining acceptance below and reviewing explicit product enablement. This reconciliation changes neither the shipping gates nor the release scope by itself.

The main gated product path is implemented: explicit profile adoption, public
token/credential/source review, registration prepare/export/finish, ordinary
profile-3 reads/writes, token-free rotation, restore, exact resume and local release
of an incomplete reservation. Signed tests cover registration on Mini, independent
Air recovery, later edits/rotation, token-free exact secret/TOTP reads and
fresh-helper reopening. Mini cancellation, interruption/resume, missing touch,
unplug, deadline, late-PIN refusal and client disconnect have scoped results.

The tested hardware is one YubiKey 5C NFC on arm64 macOS 27.0.1 (26A434).
Independent backup hardware and the entire lifecycle/platform matrix are not
qualified. A remaining macOS PIN dialog can require manual Cancel after a stopped
request; the owner accepted that temporary Preview limitation. Automatic dismissal
is not a pass. See [qualification limits](piv-recovery-signed-test.md#known-limits).

Packages remain open until their full acceptance criteria pass. An implemented
domain component or one physical scenario does not qualify every caller. No
package is newly declared qualified/released by this consolidation.
`REC-801`–`REC-803` are the [earlier feasibility track](piv-feasibility-results.md).

| Package | Implemented / observed | Remaining acceptance |
|---|---|---|
| `REC-804` Contract/compatibility | Dual-authorization design, owner decisions and AI review dispositions recorded. | Exact codecs/contexts and format freeze, capacity, platform and rollout decisions. |
| `REC-805` Cryptographic domain | Capsule, profile, recipient/wrapper/anchor codecs and exact fixtures implemented and reviewed in scope. | Final integrated byte/usage-bound review and compatibility/format qualification. |
| `REC-806` History/snapshot | Bounded anchored graph selection and complete current-snapshot verification; signed source-only recovery on both Macs. | Complete graph/hostile-input acceptance against the final protocol and supported matrix. |
| `REC-807` Native token/setup | Bound read-only reader, scoped agreement and external administration boundary; one physical key tested. | Setup instructions, certificate/key/reset lifecycle, platform matrix and remaining enforcement cases. |
| `REC-808` Registration/adoption | Durable prepare/export/finish, authenticated status and exact reconciliation; initial signed registration/adoption passed. | Remaining interrupted setup/adoption cases and independent backup registration. |
| `REC-809` Content/branches | Mutation, merge/resolution, catch-up and coverage guards implemented; edited contents recovered on both Macs. | Signed independent-Mac branch/conflict-resolution acceptance. |
| `REC-810` Authority lifecycle | Rotation, enrollment/adoption, revocation/removal, catch-up and restart domain services implemented; signed token-free rotation recovered on Air. Gated sharing commands connect recovery-profile enrollment, first trust, reviewed device revocation and exact local replacement/rejoin with scoped cancellation and retry. | Final integrated review and signed device/recipient lifecycle qualification. |
| `REC-811` Restore/resume | Verified snapshot to fresh vault; encrypted preparation and exact authenticated resume; signed separate-process reads passed. | Complete durable-phase/failure matrix and restored-vault ordinary mutation acceptance. |
| `REC-812` CLI/helper | Gated workflow, progress/touch UI, configured runtime and scoped native results recorded. | Helper/concurrency/history acceptance and signed UX review of the completed lifecycle routes. |
| `REC-813` Backup/physical lifecycle | Primary/backup software fixtures; one physical credential tested in recorded cases. | Two independently generated physical keys and the lifecycle matrix below. |
| `REC-814` Security/release qualification | Earlier integrated AI review/fixes, signed/notarized build25 installs, and full local regression on `d562c90`: 1,849 passed, one optional migration-scale test skipped, zero failed. | Final integrated review, hosted product/CodeQL checks, migration scale, compatibility/provider and exact enabled-candidate release checks. Current local regression does not qualify a hardware or shipping artifact. |
| `REC-815` Adoption/publication | Explicit gated adoption implemented and exercised on disposable data. | Supported upgrade/migration/rollback qualification, real-vault opt-in gate and authorized publication. |

Dependencies: 805 depends on 804; 806 on 805; 807 on 804; 808 on 805/806/807;
809 on 805/808; 810 on 805/808/809; 811 on 806; 812 on 807–811; 813 on 812;
814 on 812/813; 815 on 814. These identify contracts, not a requirement to finish
every physical test before dependent coding or review can start.

## Release reconciliation, 2026-11-02

The main recovery implementation is present. The remaining work is principally signed integration, hardware lifecycle and release qualification, plus explicit product enablement and any fixes those checks uncover. The package table and acceptance matrix are acceptance obligations, not a list of features still to implement. There is no technical version-number requirement to defer PIV to 0.4.0; including it in 0.3.0 would hold that release until these obligations pass.

### Evidence we can retain

- The [signed ledger](piv-recovery-signed-test.md#completed-signed-cases), E02–E04 and E15–E16, records registration, actual source-only recovery on both Macs, recovery after edits and rotation, exact secret/TOTP reads, and token-free reopening. These establish a working physical recovery path with one credential. They do not establish two independent backup keys or the subsequently added device lifecycle commands.
- E05–E14 already cover specific PIN/touch cancellation, incomplete-reservation release, saved-preparation resume, missing touch, unplug, deadline, late PIN and CLI-disconnect cases. Reuse these scoped results. Do not schedule the entire matrix again merely because the release number changes.
- The `d562c90` local xUnit reports contain 1,850 cases, one skipped and no failures. Inspected passing suites include [mixed lifecycle integration](../Tests/KeyCoreTests/V3RecoveryLifecycleIntegrationTests.swift), [enrollment](../Tests/KeyCoreTests/V3RecoveryEnrollmentProductTests.swift), [revocation](../Tests/KeyCoreTests/V3RecoveryDeviceRevocationProductTests.swift), [replacement](../Tests/KeyCoreTests/V3RecoveryDeviceReplacementProductTests.swift), [recipient removal](../Tests/KeyCoreTests/V3RecoveryRecipientRemovalProductTests.swift), [registration](../Tests/KeyCoreTests/V3RecoveryRegistrationServiceTests.swift) and [restore completion](../Tests/KeyCoreTests/V3RecoveryRestoreCompletionServiceTests.swift). These use software identities/providers; they are not new physical PIV passes. The mixed lifecycle fixture explicitly uses domain materialization for recipient addition, rather than proving hardware possession.
- The ordinary two-Mac iCloud and setup-cancellation checks in the [release record](release.md#two-mac-enrollment-and-sync-2026-10-30) are complete for the recovery-disabled format. They provide useful shared-infrastructure evidence, but do not qualify recovery-profile enrollment, removal, conflicts or provider delivery.

Build25 source is `85ee569b0487dfcf78fa4e186295c8c63f394fcc`. Comparing it with the reconciled candidate while ignoring whitespace found no changes in `PIVRecoveryAgreement.swift`, `PIVRecoveryTokenReader.swift`, or the `V3RecoveryRestore*.swift` files. This supports retaining their narrow native observations; it is not proof that their integrated callers are unchanged. Registration ownership/budget checks, runtime session continuity, lifecycle composition and the enrollment/revocation/replacement/removal product routes changed afterward. Final signed checks must target those changed paths and their integration with restoration.

This reconciliation inspected the committed ledger, source, tests and the local November 2 xUnit reports. The ledger's Mini raw `tmp/piv-recovery/` directory is absent from this checkout; those historical raw records were not reopened. Retain their committed evidence IDs and source identities, and retrieve the original records when a result needs revalidation. Do not manufacture a replacement pass or rerun hardware merely to recreate a missing local path.

### Remaining work grouped into test sessions

These groups organize the existing acceptance matrix; they do not waive its outcomes or imply a fixed count of commands, prompts or days. The owner confirmed on November 2 that a second physical YubiKey is available. Its model, firmware, credential state and suitability have not been inspected, and no provisioning is authorized by this reconciliation.

| Group | Existing evidence | Concrete remaining result / dependency |
|---|---|---|
| Independent recovery keys | One physical key recovers on both Macs; software fixtures cover multiple recipients. | Inspect the second key's compatibility and agree on owner-run external setup. Register independently generated keys with distinct anchors, keeping the other key absent as appropriate. After edits and rotation, recover independently with each key from its own registration point using encrypted source files and a fresh destination, without source-Mac credentials. |
| Macs, recovery keys and conflicts | Product commands and mixed lifecycle software tests pass. Build25 covers ordinary edits and rotation. | In a signed recovery-enabled app, enroll another Mac, exchange edits, revoke it, verify refusal, then replace its credentials and rejoin through the reviewed workflow. Exercise automatic merge and explicit conflict choices. Remove a recovery recipient and verify continuing recovery with the remaining key; separately verify the last-key warning and loss of recovery on that continuing history. Retain the documented old-copy/alternative-lineage limits. |
| Life after a restore | Real token-free reads and fresh-helper reopening passed; the new vault has no inherited registration. | Edit the restored vault, reopen it without the token, explicitly register recovery again, then recover the new vault a second time and compare its current contents. One of the independent-key sessions can supply the first restore. Anchor reuse or hardware writes require a separately reviewed external setup plan; do not overwrite a retained test registration for convenience. |
| Interrupted setup and host behavior | Specific native cancellation/resume cases passed; software tests exercise durable phases, stopped sessions and late replies. | Qualify the changed registration/adoption/rotation and lifecycle paths through signed CLI/helper interruption and exact resume. Cover helper restart and competing clients at the native boundary where software evidence alone does not prove behavior. Map each case to existing coverage first; do not repeat every software phase manually. |
| Credential, compatibility and delivery | Reader tests accept an expired self-issued certificate as a public-key container; policy/key-change rejection and generic authentication refusal have software coverage. Current discovery tests reject unsupported recovery-profile adoption. | Close same-key certificate renewal/native selection, changed-key/reset invalidation and wrong-PIN/blocked-token classification at the appropriate boundary. Simulate destructive/error cases; do not exhaust physical retry counters or reset retained keys. Test actual released-old-binary refusal on a disposable adopted source, coordinated upgrade/retained-source rollback, and missing/partial recovery-profile files on the supported provider path. Current-code parser tests alone do not establish an old binary's behavior. |
| Product and release | Source, guide and private signed/notarized Preview artifacts exist. Current local regression, style and script checks pass. | Review the integrated format/security contract and supported OS/token/capacity promises; close the public PIN-dialog policy; implement reviewed Stable/Preview enablement and signing changes; update user setup/backup/resume instructions. Run current-source hosted checks, migration scale and exact signed/notarized enabled-artifact installation/adoption checks in disposable state before publication. |

### Decisions and product changes still required

The current support target says macOS 26+ and compatible Yubico firmware 5.3+, but physical evidence covers two arm64 Macs on macOS 27.0.1 and one YubiKey 5C NFC on firmware 5.8.0. Freeze a support claim backed by the chosen qualification scope; do not silently treat a target range as a tested matrix. The format/schema and capacity promise also remain experimental until reviewed. Existing budget tests cover enforcement, not a user-facing capacity commitment.

The leftover system PIN dialog is a known unresolved UI limitation, not an untested discovery. The owner accepted manual Cancel for private Preview only. A public beta/Stable policy still needs an explicit disposition: fix it, or review and accept the documented workaround for that release. Cancellation refuses late publication; that does not establish automatic dialog dismissal. Do not reopen the same diagnostics without new evidence or a changed approach.

Public enablement requires actual source/configuration work. [RuntimeConfiguration](../Sources/KeyCore/RuntimeConfiguration.swift) restricts recovery to explicitly opted-in Preview. [KeyServiceHost](../Sources/KeyCore/KeyServiceHost.swift) constructs the recovery routes from that gate. The [Stable helper entitlements](../Config/KeyLaunchAgentHelper.entitlements) omit the smartcard entitlement present in [Preview](../Config/KeyPreviewLaunchAgentHelper.entitlements), and the [release verifier](../scripts/verify-release-artifact.sh) rejects opt-in public ZIPs. A reviewed release change must align runtime admission, app/helper metadata, signing/provisioning validation, artifact verification, tests and documentation. Removing the ZIP check alone would not enable Stable recovery. None of these protections changed during this reconciliation.

### Consolidated execution plan

Keep `codex/prepare-0.3.0` as the integration branch for the proposed PIV-inclusive release. At planning time it has twelve local commits through `297bfbe`, a clean worktree, and no remote branch or PR. The existing cancellation fix, legacy-key refusal, wording, tests and qualification records remain useful. The release is unfinished; those completed changes do not need to be restarted or split into new PRs. The current recovery-disabled publication guard remains in force until deliberately replaced by a reviewed enabled-release policy.

Use one substantive PR for the remaining implementation, fixes, documentation, qualification evidence and beta version. Keep incremental commits within it so security-sensitive changes can be reviewed separately without a PR stack. Push/create the PR only after the owner's review authorization. If a public beta is used, plan one small follow-up PR for Stable promotion and any beta findings; further PRs are warranted only by actual findings or an independently scoped change, not one per test session.

| Phase | Work and completion condition | Owner involvement |
|---|---|---|
| 1. Close the remaining design and software gaps | Review changed paths since build25 against retained evidence. Resolve support range, format/capacity promises and the public PIN-dialog workaround policy. Check credential-error classification, old-client refusal and interrupted lifecycle coverage; implement only missing behavior or demonstrated fixes. Inspect the current remote main before integrating new changes. Finish with a concrete test matrix and an isolated candidate build recipe that preserves Stable, experimental Preview and earlier test records. | Review the proposed support scope and PIN-dialog disposition. No hardware operation needed for source review. |
| 2. Prepare the independent key | Inspect the second key's model, firmware and existing PIV state without authentication or writes. Present an exact owner-run setup procedure for a compatible independent credential and anchor, preserving any existing uses. Finish with two identified independent credentials ready for disposable-vault registration; do not assume the second key is empty. | Connect the intended key and review the specific provisioning plan before any write. PINs stay in native UI; no reset or deliberate retry exhaustion. |
| 3. Complete the connected physical sessions | First register and independently recover with each key after edits/rotation. Next exercise signed Mac enrollment/revocation/rejoin, conflicting edits and recovery-key removal. Use a restored vault for edit/reopen, explicit re-registration and another recovery. Attach missing-file, cancellation, interruption/resume and competing-client checks to the affected workflows. Record exact values, source preservation, artifact identities and remaining limits. Reuse applicable earlier native passes rather than repeat the whole history. | Be present for the announced PIN, physical-touch and Mac approval steps. Agree on any external anchor changes needed for re-registration before dispatch. |
| 4. Finish public enablement and verify the candidate | Align runtime admission, Stable smartcard entitlement/signing, app/helper metadata, release verification, tests and user instructions. Keep this as a distinct reviewable commit in the same branch. Run focused checks after fixes, then the full final-candidate suite, 300-entry migration, Stable/Preview product checks and CodeQL. Recheck installed behavior affected by enablement/signing on disposable state. Reconcile all release claims and add the beta version as the last preparation commit. | Review the branch before pushing. A fresh public build number must exceed the used private builds, last recorded through 25; the current bump script merely increments the checked-in counter and must not accidentally reuse one. |
| 5. Merge and qualify the exact release package | After authorized push, use one PR and run current-source hosted checks. Merge the reviewed version, then build from clean published main as required by the release scripts. Verify the actual signed/notarized ZIP, quarantine/Gatekeeper, helper registration, recovery enablement, and representative setup/upgrade/recovery behavior in an isolated installation environment. Publish only after those checks and explicit authorization. A public beta leads to a small Stable-promotion PR, a fresh version/build artifact and its applicable package checks. | Approve publication separately. Do not replace the owner's real Stable or experimental Preview installation to satisfy package testing; arrange a separate test account or machine when shipping identities are required. |

Phase 1 preparation has begun; the review below records its completed scope and remaining decisions. A second key is available, but provisioning and physical tests are not prerequisites for inspecting code or preparing the candidate. Including PIV remains contingent on passing these checks; the current guards must not be bypassed simply to meet a version target. This plan authorizes no hardware administration, real-vault adoption, push or release by itself.

### Preparation review, 2026-11-03

Continue on `codex/prepare-0.3.0` with incremental local commits and no push. A read-only remote-main check still returned `031a2c7d763c770c01b3a28f655e4853d99467f0`; no new main changes needed integration. The [qualification runbook](piv-recovery-qualification.md) translates the remaining acceptance into connected sessions Q1–Q7 and records the fixture constraint below. This scoped review does not close the final integrated security/format gate.

| Inspected boundary | Finding and disposition |
|---|---|
| Independent registration | Earlier mixed-lifecycle tests added recipients through domain materialization. Added `sequentialIndependentRegistrationsRecoverAfterEditsAndRotation` to [registration tests](../Tests/KeyCoreTests/V3RecoveryRegistrationServiceTests.swift): two actual prepare/finish publications, separate software cards/providers, distinct original anchors, token-free edit/rotation/edit, then independent snapshot recovery with each key. The first card is not consulted during the second registration, and recovery needs no resident Mac session or owner unwrap. This closes a software integration gap, not the two-physical-key gate. |
| Lifecycle authority and publication | Inspected [lifecycle context](../Sources/KeyCore/V3RecoveryLifecycleContext.swift), [enrollment](../Sources/KeyCore/V3RecoveryEnrollmentOwnerWorkflow.swift), [revocation](../Sources/KeyCore/V3RecoveryDeviceRevocationWorkflow.swift), recipient validation and registration publication. Scope/checkpoint/session revalidation, exact review/ownership checks and unsigned budget admission are present. No production fix was identified in this inspection. Signed changed-caller, interruption and concurrency cases remain Q2/Q5; this is not an exhaustive proof of all interleavings. |
| Native error classification | [Agreement](../Sources/KeyCore/PIVRecoveryAgreement.swift) evaluates the actual key ACL and accepts only a successful callback with no error. Other authentication results become generic refusal before agreement; a failed agreement is also generic and not retried. Existing [tests](../Tests/KeyCoreTests/PIVRecoveryAgreementTests.swift) cover refused/cancelled approval, late replies and provider failure. No reliable wrong-PIN versus blocked-PIN distinction is exposed by this implementation. Retain that honest boundary; do not add guessed labels or deliberately exhaust counters. Native credential lifecycle and public error-policy qualification remain Q6. |
| Certificate and old-client compatibility | [Reader](../Sources/KeyCore/PIVRecoveryTokenReader.swift) extracts the certificate's public key rather than treating issuer/expiry as trust; its tests use an expired self-issued fixture. This does not prove native same-key renewal/selection. Current parser rejection likewise does not prove behavior of an actual released old app. Keep Q6/Q7 open. |
| Candidate isolation | Extended the existing qualification builder instead of duplicating signing/packaging. It now supports Preview, explicit recovery opt-in and build-only mode, with fresh-identity guards and app/helper metadata checks. Temporary source-plist overrides enter the normal Xcode build/sign path; default shipping metadata and runtime gates are unchanged. Four script tests cover build-only side effects, invalid recovery selection, missing component opt-in and preservation of an existing attempt. |

The original physical key already holds a retained registration. A second available key does not make a wholly fresh two-key fixture possible while preserving that registration: either authorize continuing the existing disposable vault and establish its current-source enrollment/install path, or use another unused compatible key alongside the second key for a new vault. No source-app replacement, copying of private credentials or anchor overwrite is implied. Q4's later re-registration needs its own hardware-allocation decision as well. Preparation did not inspect or change either token.

Validation: the new regression and the registration/rotation/lifecycle-context suites passed, 68 tests across three suites. The changed Swift file passed formatting and strict lint. All 30 CI-script tests passed outside the sandbox; the initial sandboxed run was blocked only because an existing timeout test could not execute `ps`. Shell syntax, project-plist syntax and whitespace checks passed. The prior full-suite result remains the applicable broader baseline; this test/tooling change did not trigger another full run.

A signed PreviewDebug qualification app built from `df8b5be` plus the retained build-input patch, namespace `piv-prep-1103`, build `1793712929`. Strict signatures, app/helper opt-in, helper smartcard entitlement and embedded LaunchAgent identity/service checks passed. The ordinary unsigned Stable Debug build and bundle checks passed with recovery disabled and no qualification namespace. Both built CLIs passed the help/alignment/version/completion checks. These apps were not installed or launched for vault operations; no PIV command or authentication prompt was opened. This is build preparation, not an installed-product or notarized release qualification.

Logs, the exact build-input patch, component hashes, metadata and tool/OS identities are retained under `.build/piv-preparation-20261103/`. All 350 before/after protected Stable/Preview file hashes and helper-registration-presence checks matched. That is the recorded preservation scope, not a whole-Keychain or whole-system audit. The remaining work is the fixture/support/PIN-dialog decisions, Q1–Q7 at their unqualified boundaries, final integrated review, public enablement and exact release-package qualification.

## Next milestones

1. **Integrated qualification.** The implementation PRs are merged. Before enabling recovery, close remaining integrated review and qualification against the final candidate. Reuse established evidence; repeat a basic two-Mac restore only for changed code or an unresolved question.
2. **Remaining lifecycle work.** Q1 independent-key recovery, Q2 two-Mac lifecycle/recovery and Q3 recovery-key removal passed at their recorded private-artifact scope. Preserve both physical anchors and the retained two-key/one-key snapshots. Next resolve the measured whole-request deadline problem and qualify a complete initial restore, then close the remaining interruption, credential and compatibility cases. Q4 re-registration and another recovery still need a separately agreed hardware allocation.
3. **Release/adoption qualification.** Freeze supported format/platform promises,
   finish regression/compatibility gates and user instructions, then qualify the
   exact release artifact and explicit adoption. Real-vault enablement follows
   813/814 and the adoption gate.

## Remaining acceptance matrix

These are required outcomes, not a separate test/commit obligation for each row.
Combine faithful cases and retain software/native evidence at its actual scope.

| Area | Required outcome |
|---|---|
| Protocol/format (`804–806`, `814`) | Exact canonical bytes, domain separation, capsule/key custody and fresh-key/nonce policy reviewed. Graph/entry and cumulative publication budgets refuse before effects; capacity never silently refreshes an anchor/floor or raises limits. |
| Graph/content (`806`, `809`) | Independent-Mac saves, automatic merge and explicit conflict choices preserve coverage. Missing parents/current ciphertext, ambiguous bases, authority/closed-epoch conflicts and invalid/over-budget input refuse without stale fallback. |
| Device authority (`810`, `813`) | Compared enrollment, joining trust, revocation, replacement, remaining-Mac catch-up and interrupted transitions honor exact reviewed decisions and continuing recovery access. Revoked Macs refuse appropriately. |
| Backup/recipients (`808`, `810`, `813`) | Q1 passed on November 3: each independent physical key recovered alone from its own floor after edits/rotation into a fresh destination namespace, without source-Mac authority. Backup registration also passed with the primary absent. Q3 also passed one/last removal: exact consent, no wrappers for removed recipients, remaining-key recovery of later edits and continued Mac access with no recovery keys. Physical setup and earlier snapshots remained unchanged. Final shipping qualification remains separate. |
| Restored vault (`811–813`) | Ordinary read/edit/reopen without the token; separately reviewed re-registration and another recovery. No silent inheritance of registration. |
| Interrupted setup/rotation (`808`, `810–813`) | Every durable phase preserves an exact resumable candidate or refuses safely. Close remaining native registration/adoption/rotation/helper-interruption cases; no generated replacement or ambiguous cleanup. |
| Credential lifecycle (`807`, `813`) | Same-key certificate renewal/expiry, replacement-key refusal and reset invalidation follow the certificate-container policy. Simulate wrong-PIN/blocked-token errors; never deliberately exhaust physical counters. |
| Host/session (`812–814`) | Lock, expiry, same-key reauthentication, disconnect, helper death/restart, multiple clients and queued setup cannot revive stopped requests, bypass ownership or install late authority. |
| Compatibility/delivery (`804`, `814–815`) | Released old binaries refuse signed unsupported-profile adoption; coordinated upgrades, migration/interruption and rollback qualify. Supported APFS/iCloud partial delivery refuses required missing state; no provider-global freshness promise. |
| Release (`814–815`) | Full tests/static/build/release checks, isolation, entitlements, notarization, quarantine and helper registration pass for the exact artifact. User docs cover administration, backup custody, recovery/resume, limits and re-registration. Publication needs explicit approval. |

## Architecture ownership

| Boundary | Owner / invariant |
|---|---|
| Format/crypto | `KeyCore` [profile codec](../Sources/KeyCore/V3RecoveryManifest.swift), [epoch boundary](../Sources/KeyCore/V3RecoveryEpochBoundary.swift), HPKE/entry codecs and schema; preserve profile-2 bytes and explicit dispatch. |
| Ordinary data | [Runtime](../Sources/KeyCore/V3RecoveryVaultRuntime.swift), [mutation service](../Sources/KeyCore/V3RecoveryVaultMutationService.swift), independent validators and existing immutable transaction kernel. Coverage is a publication invariant. |
| Authority changes | Separate rotation/enrollment/revocation/removal policies reuse epoch construction/durability and the [lifecycle context](../Sources/KeyCore/V3RecoveryLifecycleContext.swift), while retaining their own approvals and intent checks. [Catch-up](../Sources/KeyCore/V3RecoveryCatchUpCoordinator.swift) validates existing transitions without new publication consent. |
| Restore | [Snapshot verifier](../Sources/KeyCore/V3RecoverySnapshot.swift) alone supplies verified plaintext; [restore service](../Sources/KeyCore/V3RecoveryRestoreService.swift) owns scope and fresh permanent genesis/trust/selection ordering. |
| Product admission | [Protocol](../Sources/KeyCore/KeyServiceProtocol.swift), [host](../Sources/KeyCore/KeyServiceHost.swift), mutation owner and destination/config barriers. Helper owns authority; CLI supplies reviewed inputs and renders bounded output. |
| Hardware | [Reader](../Sources/KeyCore/PIVRecoveryTokenReader.swift) and [agreement adapter](../Sources/KeyCore/PIVRecoveryAgreement.swift) share native exclusion, additional to vault serialization. Administration stays external. |

Diagnostic prototypes remain evidence, not shipping transaction owners. Reuse
existing schemas, installers, signing and distribution gates; no test-only bypass
or alternate authority store.

## Review stack and evidence

The stack preserves implementation commits and targets each PR at its predecessor.
Review copy describes final code, not the investigation chronology.

| PR | Branch / scope | Published head at 2026-10-26 check |
|---|---|---|
| [68](https://github.com/tvanreenen/key/pull/68) | `codex/user-friendly-wording`: existing CLI/help | `2adba7d` |
| [69](https://github.com/tvanreenen/key/pull/69) | `codex/recovery-foundations`: format, graph, snapshot/genesis | `22a431c` |
| [70](https://github.com/tvanreenen/key/pull/70) | `codex/recovery-registration`: reader, registration, adoption | `acd6b01` |
| [71](https://github.com/tvanreenen/key/pull/71) | `codex/recovery-content`: writes, catch-up, conflicts | `c57c2d3` |
| [72](https://github.com/tvanreenen/key/pull/72) | `codex/recovery-lifecycle`: authority lifecycle | `ac06bd8` |
| [74](https://github.com/tvanreenen/key/pull/74) | `codex/recovery-restore-engine`: fresh vault/continuation | `8dec6d8` |
| [75](https://github.com/tvanreenen/key/pull/75) | `codex/recovery-service-boundary`: scoped requests/CLI | `483cbae` |
| [76](https://github.com/tvanreenen/key/pull/76) | `codex/recovery-restore`: configured workflow integration | `0ffaee7` |
| [77](https://github.com/tvanreenen/key/pull/77) | `codex/recovery-native-integration`: native fixes, interruption handling and qualification | `93303c3` |
| [78](https://github.com/tvanreenen/key/pull/78) | `codex/recovery-lifecycle-context`: shared state checks with separate approval policies | `70d2333` |
| [79](https://github.com/tvanreenen/key/pull/79) | `codex/recovery-test-support`: shared software fixtures independent of test suites | `edd3346` |
| [80](https://github.com/tvanreenen/key/pull/80) | `codex/recovery-read-capability`: exact-checkpoint reader interfaces | `943b23b` |

Stable, Preview and helper-security passes are recorded for the published heads
through 80. Each PR reports its current CI and readiness.
The three selected architecture cleanups are implemented through 80. Exact
checkpoint readers expose read policy without mutation or graph requirements;
composed runtimes retain those separate policies. Review fixes follow on
`codex/recovery-review-fixes` above 80. Their complete Release regression run is
recorded below; release acceptance remains separate. Existing stack history is preserved. Use
`gh stack` for propagation and publication. Readiness is tracked on each PR;
neither review nor green CI enables the shipping recovery gates.

| Evidence | Scope and retained decision |
|---|---|
| [Design AI review](piv-recovery-ai-review.md), 2026-10-04 | Protected random epoch signing key plus Mac signature; reduced historical replay and continuing-lineage exclusion limits accepted. Human audit recommended, not mandatory. |
| Lifecycle AI review/regressions | Fixed session-generation and exact committed-ownership checks before rotation activation. [Service tests](../Tests/KeyCoreTests/V3RecoveryKeyRotationServiceTests.swift) cover same-key reauthentication as a different session. |
| Integrated AI review/fixes, 2026-10-20 | `acd6b01`/`c57c2d3`: cumulative publication usage from earliest still-active recipient floor, including merges. `483cbae`: resident lock remains out-of-band behind queued setup. Regressions failed before fixes/passed afterward; reviewer rechecked fixes. |
| Historical full Release run | At `0ffaee776050da2a5452505b9b4c76be352e5022`, `swift test -c release --no-parallel` passed 1,754 KeyCore tests/141 suites plus six canonical-JSON tests. Opt-in large mixed migration was skipped. Raw: `tmp/piv-recovery/2026-10-20-review-fixes-full-release.log`. This is not a full run on the latest local head. |
| Native follow-up review, 2026-10-26 | At `93303c3`, three fresh AI reviewers found no actionable issue in the inspected integrated paths. A fresh full Release run reported 1,784 KeyCore tests/143 suites and six canonical-JSON tests passed; opt-in large migration was skipped. Stable, Preview and helper-security CI passed. [Qualification](piv-recovery-signed-test.md) retains exact native artifact limits. This evidence predates the lifecycle cleanup and does not qualify it or a release. Raw review/regression evidence: `tmp/piv-recovery/integrated-review-2026-10-26/`. |
| Integrated review follow-up, 2026-10-27 | Review at `943b23b` confirmed stopped-save session continuity, exact registration ownership, and pre-signing budget ordering gaps. `0e5c4e2`, `346e5cd`, and `af11331` address them; `6d0c463` keeps per-entry ownership guards bounded. Final focused verification passed 94 tests/seven suites, including 41 new CI-selected cases. The complete serial Release run on `6d0c463` passed 1,795 KeyCore tests/144 suites plus six canonical-JSON tests, without exclusions, after unlocking the Mini. The opt-in large migration case was not enabled. Current raw run evidence: `tmp/piv-recovery/review-fixes-2026-10-27/08-full-release-restored-unlocked{.log,-result.json}`. Native artifact limits remain unchanged. |
| Product lifecycle follow-ups, 2026-10-27 | The complete serial Release run on `b797333` passed 1,842 KeyCore tests/151 suites plus six canonical-JSON tests, with a clean and unchanged source snapshot. The optional large mixed migration qualification case was not enabled. Focused recipient-removal checks passed 111 tests/10 suites; final ceremony/enrollment/replacement checks passed 23 tests/three suites. The four review increments above #81 connect compared enrollment, reviewed revocation, exact replacement/rejoin and informed recipient removal. After correcting Xcode source membership, both unsigned app variants, bundle-isolation checks and built-CLI help checks passed with unchanged Swift/test sources. No new physical or signed-artifact qualification is claimed. Raw results: `tmp/piv-recovery/device-product-flows-2026-10-27/`. |

## Recording future work

Keep one current status per package and one scoped result per qualification case.
Record source/artifact identity, command or suite, outcome, material limits and
remaining gate. Update after a coherent code change or completed qualification
batch. Preparation, installation and diagnostic chronology belong in ignored
`tmp/piv-recovery/`, not parallel narratives in all three documents.

Preserve consequential failures and their disposition, including accepted limits
and what a later pass did not prove. Raw logs must contain no PIN/PUK/management
credentials, private keys or real-vault values. Local `tmp` references identify
maintainer evidence, not public artifacts or required recovery inputs. Source/test
links and immutable commits provide the portable review trail. Commit history
remains intact. Do not infer a completion percentage or mark a package released
solely because coding or a test batch ended.
