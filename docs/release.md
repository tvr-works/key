# Release notes

The checked-in [Key.xcodeproj](../Key.xcodeproj) is the project source of truth.
Use the [development workflow](development-workflow.md) to decide when a draft
stack is ready to merge and which additional qualification the release needs.

Apple-side identifiers, profiles, and notarization prerequisites are documented in:

- [apple-setup.md](apple-setup.md)

## 0.3.0 release preparation

Status on 2026-11-04: prepare `v0.3.0-beta.1` in the Preview channel with hardware recovery, including independent backup keys. Stable recovery stays disabled until a separate promotion review. Neither version has been published. The [release readiness record](0.3.0-release-readiness.md) owns the current checklist, evidence dispositions, beta limitations and final-source verification. Historical results below retain their original scope.

### What users will get

- Explicit new-vault setup with `key init`, and joining an existing vault from its synced folder.
- Simpler configuration and consistent command help, examples and individual enrollment-step help.
- Clearer authentication, status, conflict, cancellation and interrupted-operation messages.
- In Preview beta, explicit recovery-format adoption and registration of independent hardware keys, recovery after losing the Macs, and device/key lifecycle commands.
- Documentation explaining macOS approval, file syncing, retained backups and recovery limits.

Existing configured vaults do not need init or automatic migration. Legacy reads, writes and explicit migration remain supported. No legacy write cutoff or persisted-mode removal is part of this release. Recovery adoption is explicit and makes older apps refuse the adopted vault.

### Remaining gates

The necessary remaining live work is one recovery-format partial-delivery case and representative checks on the exact signed/notarized public Preview package. Reuse the completed two-key and two-Mac lifecycle evidence; do not provision another credential or repeat every interruption natively. The readiness record explains each removed test and its coverage limits.

Public Preview uses its own signed beta flag. Stable always refuses recovery. The ZIP verifier continues rejecting private-test opt-in and requires Boolean beta enablement in both Preview app and helper. The public beta accepts the documented manual-Cancel workaround for a lingering PIN dialog; Stable promotion needs a separate decision.

Run current-source automated checks and hosted CI after authorized push, then qualify the final artifact before publication. Preserve Stable, existing Preview and both physical keys. Choose disposable installation state before any live command. Local commits do not authorize a push, tag, notarization upload, release or tap update. Build 36 is planned; check the ordinary Preview artifact ledger before signing. Separately namespaced qualification timestamp counters are not the public counter.

### Single-Mac checkpoint, 2026-10-29

The owner authorized disposable single-Mac checks, preserving the Stable vault, and asked to stop before testing the second Mac. Both attempted qualification builds failed before installation: Xcode reported missing account credentials, and the installed wildcard Mac development profile excludes the currently available Apple Development certificate. The Developer ID certificate remains valid, but its installed profiles name the shipping products and do not authorize these separate qualification identities. No signing requirement or entitlement was removed to bypass the failure.

The focused setup/config/genesis/migration run passed 55 of 59 tests. Four `V2MigrationPreflightTests` failed while preparing fixtures with `Data.write(..., options: .completeFileProtection)`, before migration assertions. A standalone Foundation probe reproduced ordinary writes succeeding and protected writes failing with `NSCocoaErrorDomain 513` / `NSPOSIXErrorDomain 1`, both before and after Developer ID signing. This narrows the failure to local protected-file writes; its cause remains unresolved. The result is not a passing migration gate, and file protection was not weakened.

Before/after snapshots matched all 350 recorded Stable/Preview file hashes and helper-registration checks, including the configured vault folders. Neither product was installed, replaced, launched, locked, or authenticated by this attempt. No YubiKey operation occurred. Local evidence is under `.build/qualification-030-20261029/` (build logs, test output, protected-write probes, and snapshots); these local records are not publication assets. Shell syntax, diff checks, and refusal of the obsolete no-rebuild option passed for the revised runner. Installed setup, legacy local/iCloud upgrades, already-enrolled-vault upgrades, and migration remain unqualified; second-Mac tests have not started.

### Single-Mac follow-up, 2026-10-30

After the owner refreshed Xcode sign-in, separately identified signed Debug qualification apps built and installed successfully. Candidate app code came from `c548776`; legacy seed code came from `v0.2.0` (`a07eb607`). The additional runner change selects `local` or `icloud` legacy Keychain mode and does not change product code. The seven apps use separate helper labels, support directories, default vault paths, and Keychain services/accounts. Their timestamp build counters belong to qualification identities, not the public release counter. Signatures and embedded qualification identifiers were checked; this is not notarized release-artifact, shipping-identity, or second-Mac qualification.

| Check | Result and scope |
|---|---|
| Fresh setup | Ordinary commands refused before init; help/version worked; missing parents and nonempty folders were refused without replacement. Init in the current empty directory selected a verified vault. Another fresh setup created its missing final directory. Repeating init with an existing selection did not replace config or create the proposed destination. |
| Ordinary operations | Add/read/edit, lock, authenticated reopen, removal of the last entry, and empty listing passed. The first status request after the final lock returned recovery-required; later status and a repeated lock/status check reported ready with zero entries, without repair. The owner could not confirm whether a prompt had been cancelled, so cancellation is not established as the cause. |
| Local legacy upgrade/migration | Eight mixed entries (six secrets, two TOTP entries) seeded by 0.2.0 survived upgrade with unchanged config and matching secret hashes. Migration preserved encrypted source bytes, inventory, values, TOTP reads, subsequent mutation, helper restart, and retained-source rollback. |
| Already-enrolled upgrade | A device-enrolled vault created by 0.2.0 migration retained its config and secret value after upgrading. Edit, lock, authenticated reopen, and status passed. |
| Invalid legacy input | Upgraded app refused both migration check and apply for a deliberately corrupted fixture. Source/config bytes remained unchanged and no new-format vault was selected. |
| Interrupted setup | The isolated helper was killed after a complete durable setup receipt appeared. The CLI reported interruption, no config was selected, and the restarted helper refused another init. All receipt/vault file hashes matched before and after that refusal. This covers that interruption point, not every phase or native cancellation. |
| Legacy iCloud-Keychain source | 0.2.0 failed to store the disposable vault key (`-50`) before current-source installation. The runner retained the failure; no weaker access control or substitute key was used in that run. It did not exercise existing-key lookup/migration; the separately scoped synthetic-record check is recorded below. This is separate from iCloud Drive folder syncing. |
| Previously failing software tests | All five `V2MigrationPreflightTests` passed on the focused rerun, completing passing coverage for the 59 tests selected the previous day. The earlier local protected-write failure was not reproduced in this rerun or installed legacy writes. No protection-setting change was made; its earlier cause is not established. |
| Stable/Preview preservation | All 350 baseline file hashes and helper-registration checks matched after tests and cleanup, including configured vault folders. Only named qualification hosts were stopped and their sessions locked. Test apps, records, and encrypted fixtures remain for inspection; no real vault or YubiKey operation was performed. |

Local evidence is under `.build/qualification-030-20261030/`, including `artifacts.json`, build/test logs, probe scripts, and protected-state snapshots. The local migration corpus is `key-migration-qualification-run.M2Oasv`, invalid corpus `key-migration-qualification-run.5vZrfE`, and failed iCloud-Keychain corpus `key-migration-qualification-run.wdDekt` under the user's temporary directory. An intended cancelled setup was approved and completed; it counts only as successful explicit-directory setup. Its initial connection attempt preceded helper registration and created neither a vault folder nor local attempt state; that registration race is also retained in the logs.

Stop here until the owner is positioned for the second Mac. The next batch covers directory-based join/compare/approve/accept, independent reopen, and delayed/interrupted file delivery using disposable synced data. The follow-up sections below resolve the status error and define the supported legacy compatibility scope. Final version, shipping-identity tests, signed/notarized artifact, distribution checks, and publication remain separate gates; no release has been authorized or published by these tests.

### Status-error diagnosis, 2026-10-30

Controlled cancellation in the original isolated installed app reproduced the recovery-required message and exit 6. `V3VaultKeyHPKE.unwrap` caught the error raised while CryptoKit constructed its recipient (which invokes Secure Enclave key agreement) and replaced it with `cryptographicFailure`. The existing native authentication classifier therefore never received the cancellation. This reproduces the earlier symptom; it does not establish which button was pressed during the original ambiguous attempt.

Recipient construction now preserves provider errors for the existing native boundary, following the recovery receiver's established behavior. Ciphertext opening still normalizes cryptographic failures, and key-length, identity, and manifest checks are unchanged. A regression using CryptoKit's actual HPKE recipient with a cancelling key provider failed before the change and passed afterward; all 53 focused HPKE, checkpoint-unlock, unlock-runtime, genesis-builder, and identity-store tests passed, as did SwiftFormat, SwiftLint, and whitespace checks.

The rebuilt isolated app was tested against the same disposable vault. Approval returned healthy status; deliberate cancellation returned exit 7 and `The vault is locked. Unlock it to continue.` No repair or new vault was needed. This closes the reproduced cancellation-to-recovery error. Local evidence is under `.build/diagnosis-030-20261030/`; final release-artifact verification remains pending.

### Legacy iCloud-Keychain diagnosis, 2026-10-30

The seed failure is a native parameter incompatibility, not a missing Xcode account, cloud-delivery delay, or new 0.3.0 regression. `VaultKeyStore.storeKey` is unchanged from `v0.2.0`: it supplies both `kSecAttrSynchronizable = true` and a `SecAccessControl` carrying `.userPresence`. Apple's published [`SecItemAuthDoQuery` validation](https://github.com/apple-oss-distributions/Security/blob/db15acbe6a7f257a859ad9a3bb86097bfe0679d9/OSX/sec/Security/SecItem.m#L1657-L1660) rejects constrained access control on synchronizable additions/updates with `errSecParam`. The inspected source was pinned to that commit and matched the downloaded bytes.

A separate provisioned diagnostic app, with its own access group and a fresh UUID Keychain service, tested only public marker data on this Mac. It neither loaded nor changed a vault key. The results isolate the rejected combination:

| Synchronizable | Protection | SecItemAdd result |
|---|---|---|
| No | When unlocked, this device only, user presence | Success |
| No | When unlocked, user presence | Success |
| Yes | When unlocked, user presence | `-50` |
| Yes | When unlocked, no additional access-control constraint; public marker only | Success |

Every successfully created marker was deleted using its exact service/account selector; all cleanup operations succeeded. An earlier unprovisioned standalone probe received missing-entitlement errors and is not supporting evidence for this matrix. The valid probe's source, provisioning/signing inputs, output, and Apple-source digest are retained under `.build/diagnosis-030-20261030/`.

There is no compatible one-line change that keeps both synchronized key storage and this per-key user-presence requirement. Removing `.userPresence` would change the security promise and was not done. File-provider syncing of device-enrolled vaults is unrelated and does not require this legacy mode.

The follow-up in `bdd87b0` adds an actionable refusal before synchronized-key creation or replacement can delete an existing key. A mode change with no synchronized key refuses before loading a local key or changing configuration. Existing synchronized-key lookup, verified adoption, local mirroring, and migration metadata remain supported. No production access control was weakened. The narrower existing-record compatibility claim and its evidence follow; the rejected 0.2.0 seed remains a failure, not a pass.

### Existing synchronized-key compatibility, 2026-10-30

The compatibility boundary is an existing OS-valid synchronized record, not the ability to create one through 0.2.0's unsupported writer. A fresh signed Debug qualification app built from `bdd87b0`, under `release030-synccompat-1030`, exercised that boundary on macOS 27.0.1 (26A434), arm64, using Xcode 27.1 / Swift 6.4. The fixture used a random disposable key in a synchronized when-unlocked record without additional user-presence constraints and three generated encrypted entries (two secrets, one TOTP). It was explicitly synthetic, created through Security.framework, and never represented as released-app output. No shipping vault key was read or changed.

| Check | Result |
|---|---|
| Unsupported creation/replacement | A provisioned probe linked against current `KeyCore` refused missing-key creation and both store/overwrite calls. Existing synchronized-key digests matched after each refused write. |
| Existing source access | The installed CLI read both secrets and generated a valid TOTP code. A native authenticated read confirmed the protected local mirror contained the same key. |
| Preflight and migration | Preflight preserved config/source bytes. Apply selected the verified device-enrolled vault, retained `icloud` source metadata, and preserved all original encrypted-file hashes and secret values. |
| Continued use | A migrated-vault add/read/remove round trip and cold authenticated reopen passed. |
| Retained-source rollback | Restoring only this disposable identity's saved legacy configuration reopened the original entries. Original config/file hashes and synchronized-key digest still matched. This verifies the retained old snapshot, not recovery of later edits. |

The first focused run passed 102 tests across service/CLI, config compatibility, migration, preflight, and native-store refusal suites. Coverage includes existing synchronized-key adoption, stale local-mirror repair, mixed-key refusal, raw mode compatibility, and retained migration metadata. New creation-refusal cases cover working, stale, and absent local keys with both empty and populated sources; all leave keys/config unchanged. Additional missing-source preflight coverage checks both modes and refuses fallback to a matching key in the other location; the final preflight/parser run passed 65 tests, including the updated help. These overlapping runs are not additive test counts. SwiftFormat, SwiftLint, and whitespace checks pass for the changed Swift files.

This settles the single-Mac existing-record import question for 0.3.0 and the unsupported-creation error. It does not establish historical record provenance, cloud delivery to another Mac, or final shipping-artifact qualification. The original 0.2.0 iCloud seed remains failed and retained separately. Source and reproduction scripts, probe signing inputs, build/test logs, result JSON, and hashes are retained under `.build/legacy-compat-030-20261030/`. The qualification session was locked and only its host stopped afterward; its app, source record, and encrypted data remain available for inspection. All 350 Stable/Preview file-hash and helper-registration checks matched the pre-test baseline, including configured vault folders and installed binaries.

### Two-Mac enrollment and sync, 2026-10-30

The Mac mini and M2 MacBook Air (Mac14,2), both on macOS 27.0.1 (26A434), used the same signed Debug qualification app from `b32fb97563467c2aced0505104ebfbdc4e096501`, build `1793336623`. Namespace `release030-twomac-1030` separates its app/helper identities, configuration, Keychain service/account, and local records from Stable, Preview, and the earlier PIV fixtures. Recovery is disabled. The artifact still displays the project's pre-release-preparation version `0.2.0`; this is not a released or notarized 0.3.0 candidate. The transferred ZIP's SHA-256 was `edfd21b6d3377b9197292a7f4fa3ddb99c4d34594f23b2e701b4789a7b868da5`. The Air verified the signature and its membership in the helper's embedded development profile. The host intentionally carries only its Debug entitlement and no embedded profile.

A fresh disposable vault in `iCloud Drive/Key Qualification 0.3.0 - 20261030/vault` held two generated secrets and one TOTP fixture. The Air joined from that existing folder without `init` or `--vault-dir`. Both Macs independently produced the same comparison code and device names. Before approval, acceptance returned exit 5 with guidance to check synchronization and retry from the same folder; config remained absent and joining records unchanged. Restarting the Air's qualification helper preserved the comparison. Automatic tool approval review required explicit owner authorization for acceptance; no blocked command ran. The first invitation expired during that coordination delay, and owner approval safely refused it with instructions to create a new invitation. A fresh invitation then completed comparison, owner approval, and Air acceptance, retaining the expired attempt's records.

Acceptance selected the exact test vault and folder on the Air. Original secret fingerprints, independently calculated TOTP values, and authenticated reopening through fresh helpers passed. An Air-side harness initially expected an appended newline in piped `get` output and failed its post-add assertion. The current CLI appends a newline only for terminal output. The failed evidence was retained; because the original random input had left memory, that first add is not claimed as an exact-value pass. Subsequent deliberate edits compared fresh input bytes directly against readback and passed. The Air's added/edited entries then reached the Mac mini with exact matching digests. The Mac mini verified four entries, two active devices, healthy status, unchanged config, and another fresh-helper reopen.

The reciprocal Mac mini edit also reached the Air with exact matching values, independently checked TOTP, and healthy four-entry status. For the missing-file check, the Mac mini backed up one current encrypted test entry outside iCloud and temporarily withheld it from the synced vault. Both Macs observed that exact file missing through fresh helpers. Both `status --json` and the ordinary read returned exit 5 with synchronization/retry guidance and no secret output; config remained unchanged. The guard restored the original bytes after the Air published its observation, within its four-minute safety deadline. All 23 shared vault-file hashes matched the pre-test snapshot. Both Macs then read every current test value correctly and reported healthy status again without reinitialization or reenrollment.

An additional explicit `--allow-stale` read on the Mac mini also refused while that saved checkpoint's ciphertext was missing. No stale value was returned. The access gate retains the exact local checkpoint; it does not reconstruct missing data. The shared error now asks the user to check that required files have downloaded, without suggesting `--allow-stale` again. Read-command help explains that the files for the verified version must still be available and that the option cannot restore missing files. The observed refusal was safe; this is not evidence of a successful stale read in this fixture. This wording change does not alter read policy, error codes, or exit statuses.

All 350 Mac mini Stable/Preview file-hash and helper-registration checks matched the initial baseline. The Air reported its protected Stable/Preview state, qualification config, and expired-attempt records unchanged. Both qualification hosts and helpers were stopped/locked after verification; apps, keys, source/history, and evidence remain for inspection. The owner then stepped away, and further authentication-dependent work was paused until explicitly resumed on 2026-11-02. No PIV or real-vault operation was used, and nothing was pushed or released.

Local scripts, artifact provenance, status, comparison/approval outputs, and hashes are under `.build/twomac-030-20261030/`. Air records remain in its `key-piv-macbook-air` chat's evidence directory; compact reports were exchanged in the test folder's separate `transfer` directory. This run qualifies the observed two-Mac flow on these systems and the deliberately missing/restored ciphertext case. It does not substitute for final shipping-identity, notarization, quarantine, or distribution checks, nor establish behavior for every provider eviction policy or prolonged offline/concurrent-edit scenario.

After both investigations, all 350 recorded Stable/Preview file and helper-registration checks still matched the new diagnosis baseline. The isolated test host was stopped and its disposable session locked. No Stable/Preview installation, real vault, or YubiKey operation was used; all changes remain local.

### Cancelled setup and wording follow-up, 2026-11-02

A fresh signed Debug app under `release030-cancel-1102`, build `1793670654`, used the source committed as `d562c90`. Its separate helper, Keychain namespace, support directory, and empty local test folder preserved all earlier attempts. After the owner explicitly confirmed readiness to cancel, `init` returned exit 1 with `Device authentication was cancelled or is not currently available` and instructions to retain the unfinished setup. No configuration was selected. Status confirmed that no vault was configured; a second init refused the existing setup reservation before authentication. All recorded test-folder and support-file hashes matched before and after that refusal. The app and helper were stopped afterward, and all 350 Stable/Preview file-hash and registration checks matched the new pre-test baseline. No Air authentication or repeated enrollment was needed.

The incomplete-vault error no longer recommends a stale read that may also lack required files. Read help states that `--allow-stale` still needs the files for the verified version. All 85 focused parser, CLI, read-plan, and device-wrapped reader tests passed. The installed CLI passed the existing help, alignment, width, output-stream, and completion checks. Repository-wide SwiftFormat and SwiftLint checks passed. Local evidence, the cancellation/retry script, build logs, and preservation snapshots are under `.build/qualification-030-20261102/`. This remains separate-identity Debug qualification, not a final notarized shipping artifact.

The full software regression on `d562c90` compiled with warnings as errors and reported 1,850 tests: 1,849 passed, one opt-in 300-entry migration case was skipped, and none failed. This count includes the focused tests above; the runs are not additive. Release-script and Preview-install safety tests passed using disposable fixtures. All 26 CI-script tests passed after rerunning outside the sandbox: the initial run could not execute `ps` to check a test-owned child process. Shell syntax checks also passed. Hosted product/CodeQL checks and the migration-scale case still need final-source relevance confirmed. No source was pushed, version bumped, release artifact published, or installed Stable/Preview product replaced.

## Build the project

```bash
just build-debug
```

This builds the checked-in [Key.xcodeproj](../Key.xcodeproj) and leaves the app in Xcode's default DerivedData location under `~/Library/Developer/Xcode/DerivedData/...`.

For a signed archive that can exercise the entitled keychain path:

```bash
just build-release-archive
```

The release archive script archives the checked-in [Key.xcodeproj](../Key.xcodeproj) with the signing identities and provisioning profiles already recorded in the project and writes the archive under `~/Library/Developer/Xcode/Archives/<date>/`.
Debug builds remain automatic or unsigned for local iteration.
The bundled CLI now lives at `Key.app/Contents/MacOS/key`, the LaunchAgent helper app lives at `Key.app/Contents/Helpers/Key Agent.app`, and the LaunchAgent plist lives at `Key.app/Contents/Library/LaunchAgents/work.tvr.key.agent.plist`.

The release commands are:

```bash
just release <tag>
just bump-version <tag> <build-number>
just build-release <tag>
just publish-release <tag> <zip-path>
just publish-homebrew <tag>
```

Use tags and release names like `v0.1.0`, `v0.1.1`, or `v0.2.0-alpha.1`.
Accepted tags are strict v-prefixed Semantic Versions in one of these forms:
`vX.Y.Z`, `vX.Y.Z-alpha.N`, `vX.Y.Z-beta.N`, or `vX.Y.Z-rc.N`. Numeric
identifiers cannot have leading zeroes.
Stable tags build `Key.app` and `key`. Numbered `alpha`, `beta`, and `rc`
tags build the isolated `Key Preview.app` and `key-preview` product and publish
it as a GitHub prerelease automatically. The tag is the only release selector;
the operator does not choose the product separately.
The release tag includes the leading `v`; the app and CLI marketing version do not.
The historical version 3 prerelease checkpoints and their security boundaries
are tracked in
[v3-vault-implementation.md](v3-vault-implementation.md#alpha-release-checkpoints).

Following [Homebrew's alternative release channel convention](https://docs.brew.sh/Cask-Cookbook#casks-for-alternative-release-channels),
prereleases use separate, opt-in casks. Stable tags update `key`, while numbered
prereleases update `key@alpha`, `key@beta`, or `key@rc`. The stable cask installs
`Key.app` and `key`; prerelease casks install `Key Preview.app` and
`key-preview`. This keeps an ordinary `brew upgrade` from moving a stable
installation onto a prerelease while allowing Stable and Preview to coexist. A
tester can opt into a numbered prerelease channel, for example:

```bash
brew install --cask tvr-works/tap/key@alpha
```

The prerelease casks are mutually exclusive because alpha, beta, and rc all
install the same Preview app and CLI. Switch prerelease channels by uninstalling
the currently installed prerelease cask first. Stable `key` does not conflict
with these casks because it installs a different app and CLI.

Alpha releases through `v0.2.0-alpha.6` used the Mainstream `Key.app` identity.
Before installing the first side-by-side Preview alpha, remove that older cask
installation and reinstall the channel:

```bash
brew uninstall --cask tvr-works/tap/key@alpha
brew install --cask tvr-works/tap/key@alpha
```

## What the release workflow guarantees

The tag makes the product decision once. A stable tag selects `Key.app`, `key`,
and the `key` cask. A numbered alpha, beta, or release-candidate tag selects
`Key Preview.app`, `key-preview`, and the matching opt-in cask. The later stages
all use that same decision; there is no independent product switch to mistype.

The version bump creates an ordinary commit on a PR branch or final stack layer,
but not a tag. Merge that version through the usual checks. Building and
publication require clean local `main` matching the current remote `main` and
the requested version. The build must produce a ZIP containing the signed,
notarized, and stapled app. The final gate extracts that ZIP and verifies its
exact layout, product identity,
marketing and build versions, Developer ID signatures, hardened runtime, and
entitlement allowlists. Publication will run the same gate again.

Only after the ZIP passes does publication create and push its annotated tag.
Publication never advances `main`; its source must already be merged. The GitHub
release contains exactly the ZIP and a deterministic `checksums.txt`. A retry
uploads only a missing asset, accepts an exact published asset, and refuses to
replace different bytes or tolerate another asset. This matches GitHub's
[immutable release model](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).

`just release <tag>` stops after source release publication. Homebrew is a
separate manual checkpoint. `just publish-homebrew <tag>` uses the operator's
existing `gh` login to dispatch only
`tvr-works/homebrew-tap/.github/workflows/publish-package.yml` on `main` with
`package=key` and the version. Key does not clone, edit, commit, or push the tap,
and it stores no cross-repository credential. The tap verifies the published
release and checksum, renders the cask, runs Homebrew checks, and owns its pull
request.

`CURRENT_PROJECT_VERSION` is an internal Apple/Xcode build counter and advances
with every version bump. The semver or prerelease string is the public version.

## Operator runbook

Use the staged flow for prereleases and any release whose artifact you want to
inspect before publication. `just release <tag>` runs steps 2 and 3 for an
already-merged version. It no longer bumps the version. Step 4 always requires a
separate command.

### 1. Prepare and merge the version commit

Include the version bump in the fix PR or as the final layer of the feature
stack before marking its top ready. For a separate version PR, start a branch
from current main:

```bash
release_tag=v0.2.1
git fetch origin
git switch -c "release/${release_tag}" origin/main
just bump-version "${release_tag}" 36
```

Replace the example tag and build number with the intended release. Choose a build number above the numbers already used by signed candidates with the same application identity; consult the artifact ledger rather than incrementing only the checked-in number. Namespaced qualification apps have separate bundle identities. The script requires an explicit number and rejects numbers at or below the checked-in version. A Preview release uses a
numbered prerelease such as `v0.3.0-beta.1`.

The helper requires a clean PR branch and commits the marketing version and
incremented build counter. Review the version commit, push the PR or stack, and
pass the normal merge checks. At this point no tag or remote release exists.
Merge through GitHub or the native stack tools; do not push the version directly
to main. A small Stable fix can include this commit in its own PR and does not
need a Preview release.

Run the [applicable manual qualification](development-workflow.md#choose-additional-qualification)
on the candidate, including CodeQL before a Stable release containing production
changes. After the version PR or stack is merged, update local main:

```bash
git switch main
git pull --ff-only
```

If an older local version commit has not reached remote main, put it through a
PR first. The release commands reject unpublished, stale, dirty, or detached
source before building or publishing.

### 2. Build the final artifact

```bash
just build-release "${release_tag}"
```

The command prints the selected product, final ZIP path, and SHA-256. Do not
publish if its final extracted-artifact verification fails.

### 3. Publish the tag and release

```bash
just publish-release "${release_tag}" <zip-path>
```

This confirms clean main still matches the published version commit, rechecks
the ZIP, creates and pushes the tag, and creates or resumes the GitHub release.
It never pushes main. Keep main at that commit until the release upload
completes. The supported release assets are the channel-specific ZIP and
`checksums.txt`; the tap resolves both
from the published tag.

### 4. Dispatch the Homebrew update

```bash
just publish-homebrew vX.Y.Z[-channel.N]
```

The command validates the same release tag, dispatches the tap workflow on
`main`, and prints the repository, workflow, package, version, and resolved cask.
It does not wait for the run. Follow the printed `gh run list` command, then
review the pull request created by the tap. Stable updates target `key.rb`;
prereleases target `key@alpha.rb`, `key@beta.rb`, or `key@rc.rb`.

### 5. Smoke-test the distributed product

For an alpha Preview release:

```bash
brew update
brew install --cask tvr-works/tap/key@alpha   # first installation
brew upgrade --cask tvr-works/tap/key@alpha   # later alpha releases
spctl --assess --type execute --verbose "/Applications/Key Preview.app"
open -a "Key Preview"
key-preview version --json
key-preview status
```

Run the appropriate Homebrew install or upgrade command, not both.

For a stable release, use the `key` cask, `/Applications/Key.app`, and the `key`
CLI instead. Open the installed app once if the helper has not previously been
registered. Preview has its own configuration, vault default, helper, and
Keychain namespace, so this smoke test does not require repointing Stable Key
at a test vault.

## Failure and retry boundaries

- If the build fails, fix the cause and rerun `just build-release <tag>`; no tag
  or GitHub release exists yet.
- If source validation fails, merge the version PR or update local main before
  retrying. Do not bypass main protections or move published main backward.
- If the tag push reports failure, inspect the remote tag before retrying. A
  lost network response can leave the client unsure whether it was created.
  Publication removes a newly created local tag after a failed push; fetch the
  matching remote tag if the push actually succeeded. A conflicting remote tag
  is an error; do not replace it. Main is never updated by publication.
- If GitHub release creation or upload fails after the tag push, immediately
  rerun the same `just publish-release` command from the unchanged version
  commit with the same ZIP. It resumes missing uploads and verifies exact
  existing assets. If an existing asset differs or the release contains an
  unexpected asset, do not replace or delete it; publish a corrected build under
  a new version.
- If dispatch fails before a run is created, fix the operator's `gh` access and
  rerun `just publish-homebrew <tag>`.
- If the tap workflow or pull request fails, the GitHub release remains valid.
  Fix the tap-side problem and rerun `just publish-homebrew <tag>` without
  rebuilding or retagging. An already-current tap update succeeds without a new
  pull request.
- Do not change a published tag or reuse a version number. Correct a released
  artifact with a new version and build number.

This project currently publishes its cask through:

- [tvr-works/homebrew-tap](https://github.com/tvr-works/homebrew-tap)

No local tap checkout or cross-repository Actions credential is required.

## Test zsh completion locally

Use an isolated shell so the completion path and `compinit` order are unambiguous:

```zsh
zsh -f
autoload -Uz compinit
fpath=(/Users/tim.vanreenen/Code/key/completions $fpath)
compinit -i
```

The `fpath` update must happen before `compinit`.
If you change the completion file and want to reload it in the same shell, rerun `compinit -i`.

To test dynamic entry completion against a fake vault:

```zsh
mkdir -p /tmp/keycomp/github /tmp/keycomp/personal
touch /tmp/keycomp/github/personal.secret
touch /tmp/keycomp/personal/gmail.secret
zstyle ':completion:*:*:key:*' vault-root /tmp/keycomp
```

Then verify:

```zsh
key <TAB><TAB>
key get <TAB><TAB>
key edit <TAB><TAB>
key copy <TAB><TAB>
```

Expected behavior:

- `key <TAB><TAB>` offers `get`, `copy`, `add`, `edit`, `duplicate`, `rename`, `remove`, `list`, `unlock`, `lock`, `version`, and `help`
- `key get <TAB><TAB>` offers `github/personal` and `personal/gmail`

## Verify signing inputs

```bash
just verify-signing "$HOME/Library/Developer/Xcode/Archives/<date>/<archive>.xcarchive/Products/Applications/Key.app"
```

Use `just verify-release ...` after notarization and stapling if you want the full Gatekeeper check as well.

## Notarize and staple

`just build-release <tag>` uses the `key-notary` `notarytool` keychain profile directly.
See [apple-setup.md](apple-setup.md) for the one-time `notarytool store-credentials` command and where to create the Apple app-specific password.
