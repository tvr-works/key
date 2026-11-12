# Config simplification compatibility design

Status on November 12, 2026: `CFG-801`, explicit init, directory-based joining and hardware recovery have shipped. Stable is 0.4.1. `CFG-802` is implemented locally on `codex/maintenance-cleanup` and remains unreleased, pending CI and release qualification. The [roadmap](roadmap.md) owns release scope and records the wider cleanup audit. Earlier implementation and qualification notes below preserve their original context; they are not outstanding 0.3.0 release gates.

## Pre-change behavior and ownership

Baseline: `main` at `957d561`, with Stable `0.2.0` compatibility.

- `Sources/KeyCore/VaultLocationResolver.swift` owns parsing, writing, and verified selection. `KeyConfiguration` and the helper's runtime selection both carry a Keychain mode and optional vault ID.
- Missing `vault_id` selects v2; missing `keychain_mode` defaults to `local`. A canonical vault ID selects v3. Directory contents do not choose the model. Unknown config keys are ignored; writers always emit `keychain_mode`.
- `selectV3Vault` checks root identity and expected v2 mode, selects v3 last, and retains the source mode.
- `Sources/KeyCore/KeyServiceHandler.swift` uses mode for v2 lookup/migration. Its runtime consistency check compares directory, vault ID, and mode even for v3. Changes must preserve session invalidation and mutation ownership.
- `Sources/KeyCore/KeyCLIApplication.swift` reads config through `KeyConfigStore` and sends mutations through the helper. `ConfigKey` exposes `vault-dir` and `keychain-mode`; vault identity is not generally settable.
- Package requirements are macOS 14+ and Swift tools 6.2. No new dependency or service is needed for this cleanup.

For v3, the folder determines where ciphertext lives. An iCloud Drive folder does not require iCloud Keychain mode. For v2, mode identifies the existing source key needed for retained data; it is not a promise that a new synchronized key can be created. That old snapshot does not recover later v3 changes; see the [released continuity promise](security-continuity-recovery.md).

Qualification on 2026-10-30 confirmed that creating a synchronizable legacy key with the current `.userPresence` policy is rejected by macOS. Key now refuses synchronized-key creation and replacement before deleting a key, loading a local key for publication, or selecting an unavailable mode. Adopting an existing synchronized key still verifies all source entries before repairing the local mirror or changing configuration. Signed tests using an explicitly synthetic existing record verified read, migration, retained source-mode metadata, and rollback on one Mac. See the [native diagnosis and compatibility limits](release.md#legacy-icloud-keychain-diagnosis-2026-10-30); this does not establish historical 0.2.0 creation or cross-device delivery, and does not authorize deleting mode metadata or weakening production access control.

## Alternatives

| Approach | Compatibility and maintenance | Decision |
|---|---|---|
| Delete mode everywhere | Breaks v2 lookup/migration, loses source-mode information, and alters helper consistency semantics. | Reject. |
| Change help text only | Preserves bytes but leaves callers interpreting an unrelated mode and optional ID. | Insufficient as completed cleanup. |
| Explicit runtime selection; retain old file representation initially | Separates active authority from compatibility metadata without another durable file. | Recommended first slice. |
| Immediately move mode into a permanent sidecar | Shortens config but adds ordering, identity binding, missing-record, and old-writer problems to normal v3 operation. | Do not build by default; prefer retaining source-mode information within the bounded legacy migration path. |

## CFG-801: explicit selection, preserved file compatibility

Introduce one internal active-authority value: v2 carries `KeychainMode`; v3 carries its canonical vault ID. Keep the root in the enclosing runtime selection. Parse the file once into this model. Do not add an independently editable format selector. Start internally rather than breaking public initializers merely to rename fields.

Retain legacy mode for the codec and migration boundary, not v3 cryptography. Keep current emitted file bytes and source-mode values on ordinary writes, including migrated `icloud` selections. Preserve the helper's conservative mode-change check as a separate compatibility-field comparison. An explicit authority model is not permission to weaken existing guards.

Shipped CLI contract through 0.4.1 (superseded by the unreleased CFG-802 behavior below):

- `config list` reads one snapshot. V2 retains `vault-dir` and `keychain-mode`. V3 lists `vault-dir` only; help explains that enrollment supplies authority.
- Explicit `config get keychain-mode` retains raw `local` or `icloud` stdout during deprecation for script compatibility. For v3, stderr explains that this is retained legacy metadata, not the active key-storage model.
- Setting mode remains available for v2 and refused for v3. Explain v3's folder-backed storage and device enrollment in the refusal.
- `vault_id` stays managed by verified workflows, not a general setter.

The v3 list change is observable and needs release notes and tests. Do not replace `get` output with prose or an invented mode such as `none`. No new CLI command or JSON schema is required. Choose the release version after reviewing implementation scope, not as part of this design.

## V2 retirement direction

Plan updated November 12, 2026: announce retirement in 0.5, remove normal v2 operations at 1.0, and retain explicit migration. The warning and explicit init stages have shipped. Legacy reads and writes remain supported until 1.0; no intermediate read-only release is planned. The [roadmap](roadmap.md#legacy-retirement-05-notice-10-cutoff) owns this schedule.

| Stage | Proposed behavior | Gate before release |
|---|---|---|
| Shipped warning/setup stage | Announce v2 deprecation when v2 is selected and direct users to `key migrate --check`. Require explicit v3 setup for new vaults. Existing v2 vaults remain usable. | Completed for the released scope. |
| `0.5` retirement notice | Name 1.0 as the cutoff in the existing terminal warning and release guidance. Keep legacy reads, writes and explicit migration working. | Update warning copy and tests; document migration and the route for users who skip releases. |
| `1.0` explicit migration only | Remove v2 from normal runtime and ordinary config choices; retain a narrowly scoped v2-to-v3 importer and a documented path for old installations. | Prove users can reach the importer without a working v2 normal runtime, identify their source mode, and recover from failed migration without source loss. Qualify local/iCloud migration, interruptions, unavailable hardware, skipped-release upgrades and multi-Mac enrollment. |

Warnings must not contaminate secret stdout or machine-readable output, introduce surprise prompts in scripts, or change success exit codes during the warning stage. The diagnostic channel and frequency are defined below. Enforce removal of normal legacy operations in the helper, not just in CLI presentation. Keep source inspection and authentication available through explicit migration.

### Implemented warning boundary

The warning appears once on stderr for each v2 `key status` (including `--verbose`) or `key config list` invocation whose stdout is a terminal. `status --json` never emits it, even in a terminal. Redirected/piped stdout suppresses the retirement warning. No stored dismissal flag, timer, authentication, or migration operation is added.

The terminal warning now says legacy vaults will require migration in Key 1.0 and points to the read-only `key migrate --check` and migration help. Help explains that reads and writes remain supported until 1.0, explicit migration remains available afterward, and users may upgrade directly from older releases. Neither the warning nor help claims that a particular unhealthy vault can be read or changed successfully.

Status uses the helper's reported format without loading local config. Config listing uses one loaded configuration for both values and the warning decision. Missing or malformed payloads/configs keep their existing errors and do not produce an additional retirement warning. Human status health and exit codes remain unchanged.

Routine secret reads, copy, mutations, unlock/lock, migration commands, and raw `config get` receive no new warning. This intentionally limits discovery to explicit inspection commands and help. Warning on every operation would either require extra selection reads or response metadata and would add noise to normal secret use. Explicit terminal inspection fits the existing CLI boundary without changing the helper protocol or machine-readable schema. A later enforcement stage must not depend on users having seen this warning.

Migration remains explicit. Installing an update must not convert a vault, delete its old files or Keychain items, or silently block all access to its secrets. Users can skip the warning release, so later versions must explain the migration route themselves. Unsupported hardware or failed preflight must leave the source accessible through a documented compatible reader or migration path, not an automatic repair.

Coordinate the other Macs before migration: they can otherwise keep writing to the old snapshot, and those edits do not enter v3. Require a clear continuity/recovery decision before enforcing the write cutoff. Hardware purchase is not a migration prerequisite. Hardware recovery has shipped, but registration remains explicit and is not required to migrate.

### New-vault installer foundation

New-vault creation has a separate internal entry point, `V3DeviceWrappedGenesisInstaller.installNewVault`. It shares migration's identity persistence, random vault-key generation, wrapped-key verification, immutable manifest publication, checkpoint/cache installation, and verified reopen. It does not read or create a v2 key. The migration entry point retains its existing source checks, including the requirement for an existing v2 key when migrating an empty v2 vault.

Loosening that empty-migration check would make a missing key look like permission to initialize another vault. A separate creation path keeps that distinction explicit without duplicating the cryptographic installation pipeline. The initial foundation required the installer to create a new child directory. The agreed CLI contract now also accepts an explicitly selected existing empty directory through `V3NewVaultDirectory.prepare`. Nonempty directories, files, and destination symlinks remain refused. This is a deliberate UX tradeoff: an explicit init requests creation, but neither an empty listing nor creating a directory proves that a sync provider has finished delivery.

The directory reservation is process-local and single-use once installation begins. Root and parent identity checks refuse observed replacement. Before selection, the installer requires the root to contain only this attempt's genesis manifest and rechecks its exact bytes. Unexpected delivered files, identity changes, and interrupted phase checks prevent selection and invalidate the attempted session. These checks detect observed filesystem changes; they do not lock out a sync provider or another process.

Failure can leave the directory, identity, published manifest, or local verification state for inspection. The installer removes only its own recognized staging artifacts; it neither deletes the destination nor silently adopts it for another attempt. The in-memory reservation alone is not a durable recovery record. The setup workflow below adds a persistent attempt record before creating an identity. No implicit default-format switch is included.

### Explicit initialization command

`key init` initializes the current empty directory. `key init <directory>` resolves relative paths against the CLI's working directory and creates only the final directory if missing. Its parent must exist. `--` permits a path beginning with a dash; there is no `--force`, no separate config-selection step, and no existing-vault reinitialization. CLI warnings identify this as new-vault creation, direct other-Mac users to enrollment, and disclose the current permanent-loss boundary before requesting key creation. Secret stdout formatting is unchanged.

`KeyServiceHost` owns the unconfigured-to-configured transition under an exclusive request barrier. It composes the ordinary `KeyServiceHandler` lazily and preserves its existing request/mutation ownership once selected. This keeps initialization out of v2 runtime composition. Unconfigured utility status reports a locked session without creating configuration; lock succeeds without reading config. All other unconfigured helper requests report that setup is needed. Existing configurations still use the selected runtime, but ordinary legacy bootstrap has been removed. Init refuses any existing config object or already composed runtime instead of switching it.

`V3VaultInitializationService` prepares the destination, reserves its attempt through `KeyConfigStore`, then invokes the verified installer. The local `v3-init-attempts/<filesystem-device>-<file-id>.json` record stores the operation ID, destination path, and filesystem identity before any device identity is created. It contains no keys. The existing durable no-overwrite writer prevents concurrent attempts from reserving the same directory identity, including through a renamed directory or ancestor-path alias. Records remain as inspection receipts after success; they are not part of v3 key authority, a legacy-source record, or a catastrophe-recovery mechanism.

Config selection requires that no config has appeared, that the root and config-directory identities still match, and that the attempt record is unchanged. The existing atomic no-overwrite writer publishes the complete config last, so a racing config writer is not replaced. The existing file representation, including `keychain_mode = "local"`, is retained for compatibility. The helper marks selection as requiring restart; the CLI uses the existing post-reply shutdown handshake. A restart timeout after successful init directs users to status, not another init.

An interrupted attempt is not automatically resumed or deleted. If config was published, status after restart opens the selected v3 runtime. Otherwise, status explains that no vault is selected, and another init in the same directory is refused by its contents or durable attempt record before another identity is created. Inspect the preserved directory and receipt before any manual cleanup. A new unused destination can be initialized explicitly, but that does not recover or delete the prior attempt. Automated resume/cleanup and signed-app/iCloud interruption qualification remain follow-up work; simulated interruption tests do not establish power-loss behavior on a provider.

### Explicit setup required for new vaults

`KeyConfigStore.load()` is read-only. Absent config produces setup guidance without creating App Support directories or a default vault. Existing config must name an available real directory, not a file or destination symlink. Config setters also require an existing config, and setting `vault-dir` requires an existing destination. File parsing, retained mode, and the missing-ID interpretation of existing v2 configs are unchanged; an absent config is no longer treated as a new v2 selection.

Ordinary v2 unlock and add operations load only existing keys. Local lookup never requests generation, and iCloud lookup may mirror a verified existing synchronized key locally but never generate a new one. Missing keys refuse even when the configured vault is empty. Existing v2 content writes and migration remain supported; this is removal of implicit setup, not the planned v2 content-write cutoff.

The helper retains the opened root identity and checks it before ordinary configured requests. An observed removal or replacement invalidates the session and refuses the operation. These checks do not make legacy path-based storage transactional against a concurrent filesystem change. Lock and deliberate root correction remain available. When the old folder is unavailable before runtime composition, the host serializes an explicit root setter under its request barrier, preserves the existing selection, invalidates the key session, and requires restart without opening the old vault.

The first-time enrollment entry point is now implemented locally. An unconfigured Mac uses the current directory for `share invitations`, `share join`, `share compare`, and `share accept`, with `--vault-dir <existing-directory>` available when running elsewhere. A configured Mac uses its configured root regardless of the current directory. An explicit different root is refused. The CLI resolves and displays an absolute path; the host checks the selection independently and serializes these requests against initialization, root changes, and configured work. No parent search or directory creation is included.

The considered alternatives were requiring the directory option on every unconfigured command or using the current directory with an optional override. Both can retain the same trust checks. The current-directory form fits the agreed init UX without requiring a hidden pending-vault default. The directory identifies transport only; it does not establish vault authority. `shareInDirectory` is a separate request kind, so an older helper cannot ignore the path and dispatch the request against its own default selection.

`V3UnconfiguredEnrollmentService` admits joining-side operations without composing a legacy runtime. Discovery only lists the existing mailbox; it creates no config directories, identity, or cache. Join authenticates the exact unexpired invitation before reserving a local root record or entering identity work. Compare without a joining request ID and accept require the existing binding. Inviter commands, device replacement, and ordinary vault operations cannot enter through this unconfigured route. Configured requests delegate to the existing handler, preserving its mutation and replacement-enrollment boundaries.

`KeyConfigStore.prepareEnrollmentSelection` installs a durable no-overwrite `v3-enrollment-roots/<invitation-digest>.json` record containing the version, invitation, vault ID, absolute path, and filesystem identity. An exact join retry can reuse it; a copied, renamed, substituted, or conflicting root cannot. The final selector checks the root, config-directory identity, unchanged binding, and absent config before atomically publishing the full v3 selection. Records remain after success and contain no secret keys. They do not replace the Keychain-held signed ceremony or authorize acceptance. The existing device-wrapped adoption workflow verifies approval, installs local trust, verifies reopen, and then calls this selector. The one-request unconfigured session is invalidated on exit. Successful acceptance requires helper restart; no temporary v2 config is written.

After an interrupted acceptance, the same folder and exact ceremony can retry through the existing adoption recovery checks, including an already-consumed approval whose config selection failed. A racing config writer is never overwritten. If config was already published, status after restart is the next step, not a new join or init. Lost or changed binding records require inspection, not automatic replacement. Signed-product enrollment and provider-interruption qualification remain release gates even though the unconfigured entry-point blocker is implemented.

## CFG-802: shorter v3 file with a bounded legacy path

Design and local implementation, November 11, 2026. Working release target: 0.5.0. This section describes the unreleased code, not behavior installed by the published 0.4.1 package.

### File and CLI behavior

The canonical v3 file contains `vault_dir` and `vault_id`, without `keychain_mode`. New init, enrollment and recovery write this representation. Migration and existing config setters use it when they next save a v3 selection. Loading config, status, completion, app launch and installing an update remain read-only. An existing longer config stays valid until an authorized save; there is no background upgrade and no new cleanup command.

| Alternative | Decision |
|---|---|
| Rewrite existing files during load | Reject: turns diagnostics and ordinary startup into a persistent transition and can race the running helper. |
| Add a cleanup command and a permanent provenance sidecar | Reject for this scope: adds a user step and ongoing runtime dependency for information needed only at the legacy boundary. |
| Preserve the original config, then shorten it on an existing authorized save | Choose: reuses config ownership and restart behavior, leaves reads unchanged, and retains the exact old choice without making it current-vault authority. |

Keep both old v3 modes readable, including `icloud`, and preserve rejection of malformed or duplicate fields. For v2 only, an omitted mode retains its historical `local` meaning. For v3, omitted mode means no legacy field was supplied; it must not become invented source-mode information.

Preserve existing read compatibility for symlinked config files/directories. Writes require a regular file under a retained real directory and refuse redirected paths with guidance to preserve the existing config. Reading a dotfile link is not permission to rewrite its target or archive outside the product's local metadata directory.

In the target release, `config get keychain-mode` on any v3 selection refuses with an operation-refused exit, empty stdout and a brief explanation: "This vault uses device enrollment. keychain-mode applies only to legacy vaults." V2 get/set/list keep their existing behavior. V3 set remains refused, including at the config-store boundary rather than only in the helper. `vault_id` remains managed by verified workflows.

An existing config is shortened on its next successful save through those workflows. A deliberate `config set vault-dir` to the current directory can request a save through the existing helper path. It must preserve the selection and use the usual session invalidation/restart; it is not a way to join, migrate or repair a vault.

### Retain exact configs before removing information

Use exact config snapshots rather than a new permanent metadata service or a field renamed to `legacy_mode`. Before replacing a file that contains `keychain_mode`, retain its original bytes under this product's local App Support directory at `legacy-configs/<selected-vault-id>/<sha256-of-original-bytes>.toml`. Migration must retain its original v2 config before selecting the verified destination ID, even when the source omitted mode. New init and enrollment have no previous config to archive.

The bytes retain the original configured root, explicit or omitted local/iCloud mode, old vault ID if present, comments and unknown fields. The containing directory associates that snapshot with the selected v3 ID. This is configuration preservation, not proof that a v3 config came from migration: previously enrolled-only configs also carried a mode, so do not label them as confirmed v2 sources. A digest names the exact bytes; it does not authenticate the source or authorize a rollback.

Keep the directory private and snapshots owner-readable/writable only. Use the existing retained-directory/no-overwrite writer patterns, reject symlinks and nonregular objects, and verify an existing same-name snapshot against the expected bytes. Repeating the same save reuses the exact snapshot. A different old-writer result gets a different digest and cannot overwrite the earlier `icloud` snapshot. Limit each archived config to 1 MiB; an oversized source may still be read, but shortening it must refuse with inspection guidance and leave the active file unchanged. Never silently truncate it or remove unknown fields before preserving it.

Archives are local and optional for ordinary v3 access. Missing or malformed archives cannot block an otherwise valid v3 vault, select v2, create a key, or adopt provider history. Inspect retained v2 data only through a deliberately selected compatible legacy reader/config; verify its actual source rather than trusting an archive filename. After ordinary v2 support is retired, provide the explicit importer route. Neither route treats old entries as the current vault or recovers changes made after migration.

Do not delete snapshots automatically. Document their location and limits when the implementation ships. They contain no protected vault keys, but can contain personal paths and user-supplied unknown settings, so they must not be uploaded as routine diagnostics.

### Ownership and interruption order

`KeyConfigStore` continues to own parsing, snapshots and persistence. `ConfiguredVaultAuthority.v2` carries the effective legacy key mode; `.v3` carries only the selected vault ID. Represent the optional retained v3 field separately, and compare it in the running helper's selection snapshot. An external field removal or an old writer adding/changing it must still invalidate the session and refuse work until restart. Do not weaken the current mode-change guard merely because the field no longer controls v3 cryptography.

The existing service-host request barrier serializes explicit configuration transitions, initialization, enrollment and migration. Retain expected root/config identity checks and selection validation. Changing the path while the old root is unavailable must still work through the existing correction path; archiving config must not require opening that unavailable old vault.

For a save that removes legacy information: read and validate the expected config, durably install/verify its exact snapshot, recheck the expected selection and filesystem identities, then publish the shorter config through the existing atomic writer. Before migration selection, retain the original root/mode guards and verified destination reopen. The archive is a prerequisite for removing information, not a second commit record or authority for the vault.

An interruption before archive completion leaves the original config. An archive without a new config is harmless and reusable. After config publication, restart opens only the selected v3 vault. A retry rechecks the actual saved state; it must not replay selection from an archive or launch a new migration. Refuse observed concurrent changes without overwriting them. The host barrier and rechecks do not claim to lock out an arbitrary external writer or sync process.

### Older apps and intentional compatibility breaks

The current reader already accepts a v3 config without mode, but its old `config get keychain-mode` reports the default `local`, and an old writer puts that value back. That reported value is not source provenance. A later new writer must preserve that distinct file without replacing the earlier snapshot. Test the round trip using the released parser/writer behavior, including an original migrated `icloud` selection.

The field removal does not change vault bytes, device identity, history or recovery registration. It does not make apps that lack support for recovery-enabled vaults compatible. Downgrading or restoring a config is not a supported method of recovering a current vault from older files.

Recovery resume accepts the exact canonical restore config written by 0.4.1, including its `local` mode line, as well as the new shorter canonical config. The destination ID and directory identities must still match the owned preparation, and trust must be freshly verified. Resume keeps the exact existing bytes instead of rewriting them. Different mode values, whitespace changes, paths, IDs or unsafe objects remain refused; arbitrary equivalent TOML is not sufficient.

Remove the v3 mode getter compatibility behavior and the deprecated `--totp` alias together in 0.5, with explicit release notes and actionable errors. Keep Argument Parser's layout and the canonical `--totp-secret` flag. Announce the 1.0 removal of normal legacy operations in 0.5; the importer-only runtime transition remains separate implementation and qualification work for 1.0.

### Required implementation coverage

| Boundary | Required proof |
|---|---|
| Canonical writes | Init/enrollment omit mode; v2 still retains its actual choice; migration and root saves shorten v3 only after preservation. |
| Read compatibility | Local, iCloud and omitted modes; both vault models; no byte rewrite, helper contact or invented v3 source mode. Invalid/duplicate fields retain their errors. |
| Snapshot safety | Exact bytes including unknown fields; idempotent retry; original v2 omitted mode; previously enrolled-only v3; unsafe/mismatched archive objects; size limit; source/parent replacement and failed writes. |
| Commit boundaries | Failure before archive, after archive and after config publication; no replacement of observed changed selection; no automatic selection or key creation from retained files. |
| Session and root changes | External mode addition/removal/change still refuses; normal restart opens the same vault; deliberate correction works when the old root is unavailable. |
| Older writer | A released writer reads the shorter file, adds `local`, and the new writer preserves it without losing the original `icloud` snapshot or selected ID. |
| CLI | V3 getter refuses with empty stdout; v2 getter/setter remain compatible; removed `--totp` gives canonical-flag guidance; help/completions and secret stdout stay correct. |
| Migration | Both source modes, missing existing source key, source/root changes, cancellation, selection interruption, verified reopen, and unchanged original entry bytes. |

Start with the existing config, root-coordination, init, enrollment-selection, parser and migration suites. Use synthetic homes/keys and fault injection through existing storage seams. Run the full PR checks and the migration-scale gate before release. A separate signed disposable check must establish saved-selection reopen and helper restart if those paths change. Reuse qualified hardware-recovery behavior; no new physical-key ceremony is justified by a config-only change.

## Verification

| Boundary | Required cases |
|---|---|
| Files | V2 local/iCloud, omitted mode, and v3 with both retained modes load without changing selection or rewriting bytes. |
| Parser | Missing directory, invalid/duplicate mode or UUID, quoted paths, existing unknown-key behavior. |
| CLI | Snapshot-consistent list, exact get stdout, v3 stderr explanation, v2 setters, v3 refusal, relevant help/completion updates. |
| Helper | Changed directory, identity, mode, missing/malformed config still invalidate/refuse; lock/restart remains required. |
| Migration | Both source modes, root replacement, mid-migration mode change, interrupted selection, verified reopen, unchanged v2 source. |
| Enrollment | Interrupted selection retries the verified ceremony without arbitrary identity mutation or replacement. |
| Later persistence | Old/new readers and writers, crash boundaries, source-mode retention, deliberate retained-v2 rollback. |
| Retirement | Warning output/exit compatibility, helper-enforced write refusal, permitted access/migration operations, skipped releases, unsupported hardware, and other Macs still on the old snapshot. |

Start with `CryptoAndStorageTests`, `VaultRootChangeCoordinationTests`, `KeyProductIdentityTests`, and `V3LocalMigrationTests`. Extend CLI/enrollment tests for changed behavior, then run the full Swift suite and release checks before qualification. Use temporary homes and disposable vaults throughout.

Preparation check on 2026-09-05: all 42 tests in those four suites passed. The initial sandbox run could not access Swift's compiler cache; the host-level rerun passed. This validates the existing baseline, not the proposed behavior. No full suite or release qualification was rerun for these documentation edits.

## Shipped CFG-801 behavior and historical verification

The notes in this section describe the earlier implementation and its checks at the time. Later signed qualification and releases are recorded in [release.md](release.md). Their pending statements do not supersede the current release status.

V3 `config list` now omits `keychain-mode`. Scripts explicitly requesting `config get keychain-mode` still receive the same raw value on stdout, with an explanation on stderr. Existing v2 config values remain compatible; terminal config listing now adds the retirement warning described above. Config mutation no longer creates a config or destination folder, and ordinary commands no longer create v2 keys. The persisted mode field remains for compatibility; users should not manually remove it as part of this update.

`ConfiguredVaultAuthority` distinguishes v2 key storage from v3 identity internally. Runtime composition and verified migration use it, while the helper still refuses unexpected changes to retained mode metadata. Config listing reads one snapshot. Public configuration initialization and the on-disk representation remain compatible. No parser or completion token was removed.

`ConfigCompatibilityTests` covers six read/CLI combinations (local, iCloud, or omitted mode, with v2 or v3 selection), both migration source modes, mode-change invalidation in both models, and four malformed configs. Existing service tests also check the v3 mode-change explanation.

Implementation verification on 2026-09-05: `swift test --no-parallel` passed all 761 tests in 71 suites. Release target/publication/Homebrew dispatch tests and Preview install safety tests passed, as did whitespace checks. SwiftPM built the CLI and helper; no installed-product or signed-release qualification was performed.

Normal parallel runs were not clean: existing concurrency tests exceeded one-second semaphore deadlines, with a downstream error mismatch in one test. An isolated archive of pre-change commit `6cfbd27` reproduced the same failures (757 tests, 70 suites, five issues), so they predate this implementation. The serial run retains those tests' internal concurrent operations. Test scheduling reliability remains follow-up work; these results are not a claim that the normal parallel release gate passes.

Warning-slice verification on 2026-09-05: 116 focused tests passed, followed by a complete serial rerun with all 765 tests in 72 suites passing. Both release-script suites and whitespace checks passed. The first full serial run encountered one `.invalidSignature` error in the unchanged `sharedEnrollmentRejectsMembersAndExistingDevices` test; its 12-test suite and the full serial suite passed on rerun. The cause of that intermittent signature failure has not been diagnosed. No crypto code, installed product, or hardware was changed, and no release qualification is claimed.

New-vault foundation verification on 2026-09-05: all 30 focused tests in three suites passed, followed by all 775 tests in 73 suites with `swift test --no-parallel`. Coverage includes creation without a legacy key, 14 interruption boundaries, occupied destinations, invalid names, parent/root replacement, unexpected delivered data, and preserved migration checks. An unsigned `KeyCLI` Xcode build and both release-script suites passed. All vault fixtures were disposable; no installed app, live configuration, vault, or hardware was modified. Signed-release and production setup qualification remain pending.

Init-command verification on 2026-09-05: the initial focused run passed 57 tests in four suites. After adding config-directory replacement and concurrent-init tests, the complete serial suite passed all 791 tests in 74 suites. The CLI-to-host-to-installer tests exercised both current-directory initialization and creation of a named directory using software test identities and temporary homes, including verified genesis and final config selection without v2 bootstrap. Tests also cover durable refusal after restart/rename, existing and racing config writers, changed receipts, path escaping, request coding/authorization, and helper restart messaging. Unsigned Xcode CLI and full app/helper builds, both release-script suites, completion syntax, and whitespace checks passed. The full app build emitted only App Intents metadata-extraction warnings for targets without that framework. After targeted registration cleanup, a Launch Services inspection found no entries for the temporary app build. No installed product was launched or updated, and no live vault or hardware was used. Signed-helper authentication, real Secure Enclave creation, and iCloud interruption behavior for init remain unverified.

## Historical enrollment and explicit-setup checkpoint

Directory-enrollment verification on 2026-09-05: all 812 tests in 76 suites passed with `swift test --no-parallel`. Focused checks cover both folder forms, relative paths with spaces, configured-root precedence, malformed-config refusal, request authorization, read-only discovery, no missing-folder creation, persistent invitation/root binding, and existing revoked-Mac rejoin behavior. The CLI-to-host-to-adoption test uses prebuilt signed joiner state and software identities to exercise both directory forms, helper restart, missing approval, a copied folder, a wrong comparison code, and retry after a consumed approval fails config selection. It verifies that the approved checkpoint/cache and unwrapped key are usable before config selection, without reading or writing a legacy vault key. The unsigned Xcode CLI build, release-script tests, Preview install safety tests, completion syntax, and whitespace checks passed. The earlier protected-file test failures did not reproduce in this run; their cause remains undiagnosed. No installed app, real vault, live config, or hardware was changed. Signed-helper authentication, real Secure Enclave enrollment, and iCloud interruption qualification remain pending.

Explicit-setup verification on 2026-09-05: all 95 focused tests in seven suites passed, including no-config refusal, no key generation for empty local/iCloud v2 vaults, missing/replaced roots, lock/help/version before setup, and correction of a moved v2/v3 root without composing the old runtime. The unsigned CLI build, release-script tests, Preview install safety tests, and whitespace checks passed. The complete serial run executed 800 tests but failed with 65 issues across 30 tests. An untouched archive of the pre-change branch at `e31d345` reproduced those same 30 failing tests and per-test issue counts in its 791-test run. The failures originate in existing protected temporary-file writes and downstream assertions after those writes fail. The cause remains undiagnosed; file protection was not weakened, and this is not a clean full-suite or release qualification result. No installed app, live config, real vault, or hardware was used.

At this checkpoint, setup/config work was merged and 0.3.0 signed qualification remained to do. Subsequent releases completed that work and enabled hardware recovery. V2 content-write enforcement, normal-runtime removal and automated failed-init recovery remain separate work; the current `CFG-802` design above replaces the earlier unspecified persistence follow-up.

## November 11 design baseline

On branch `codex/config-retirement`, the unchanged production code passed 103 tests across `CryptoAndStorageTests`, `ConfigCompatibilityTests`, `VaultRootChangeCoordinationTests`, `V3LocalMigrationTests` and `CLIParserTests` using `swift test --no-parallel --force-resolved-versions --filter 'CryptoAndStorageTests|ConfigCompatibilityTests|VaultRootChangeCoordinationTests|V3LocalMigrationTests|CLIParserTests'`. These tests establish existing behavior, including both retained modes and mode-change invalidation. They do not verify the proposed `CFG-802` implementation. Fixtures used temporary homes and synthetic key providers; no installed app, real vault or physical key was involved.

## Local implementation verification, November 12

Source: `bc56824`, on the renamed `codex/cli-config-cleanup` branch. All fixtures used disposable homes, synthetic entries and software key providers. No installed application was launched or replaced, no real vault was selected, and no physical key was inspected or changed.

| Check | Result and scope |
|---|---|
| Final focused Swift run | 146 tests in 11 suites passed. Covers config preservation/privacy, source/parent/target replacement, interrupted saves, old-writer output, helper invalidation, linked-config read compatibility, getter/flag refusals, init/enrollment selection, CLI wording and exact older restore-config continuation. |
| Migration scale | The opt-in 300-entry mixed secret/TOTP case passed with unchanged legacy source bytes. This does not qualify native hardware or an installed app. |
| Strict compilation | `swift build --build-tests --force-resolved-versions -Xswiftc -warnings-as-errors` passed for the final source. |
| Unsigned Preview | Release build and bundle checks passed. Its bundled CLI passed standard help layout/width/output tests and real zsh Tab checks in temporary homes. The app/helper were not launched, installed or authenticated. |
| Older source | A config-only probe built from released 0.4.1 source `027c845` accepted the shorter config and rewrote its default `local` field. The current writer removed it while preserving both exact versions and the selected vault ID. This is parser/writer qualification, not execution of the old shipping app. |
| Repository checks | SwiftFormat, strict SwiftLint, 46 CI-script tests, release/Preview script fixtures, shell syntax, dependency pins and local documentation links passed. |

The broad run exercised 1,919 tests across 155 suites, with the opt-in scale case intentionally skipped there. It reported 33 failing tests with 76 issues: two obsolete wording assertions, updated and passing in the final focused run, plus 31 tests failing around protected legacy-fixture writes. The same single protected-write failure reproduced against unchanged released source, and a standalone Foundation probe failed in three disposable locations. Later, without changing protection flags, the probe passed and the same 31 tests passed on both released and final current source. The cause of that intermittent local condition is unresolved. These reruns do not constitute one clean full-suite result; CI and release qualification remain required.

Private local evidence is under `.build/config-cleanup-compatibility/` and `.build/verification/`; it is not a publication asset. The [roadmap](roadmap.md) retains the release gates. Do not repeat hardware registration or use the real vault to compensate for a software-fixture failure.
