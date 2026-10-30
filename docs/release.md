# Release notes

The checked-in [Key.xcodeproj](../Key.xcodeproj) is the project source of truth.
Use the [development workflow](development-workflow.md) to decide when a draft
stack is ready to merge and which additional qualification the release needs.

Apple-side identifiers, profiles, and notarization prerequisites are documented in:

- [apple-setup.md](apple-setup.md)

## 0.3.0 release preparation

Status on 2026-10-29: feature work is merged; release qualification is in progress. The intended sequence is `v0.3.0-beta.1` in the ordinary Preview channel, followed by `v0.3.0` Stable. Neither version has been published. This section owns the 0.3.0 checklist; the recovery plan owns the separate gates for enabling recovery.

### What users will get

- Explicit new-vault setup with `key init`, and joining an existing vault from its synced folder.
- Configuration output that describes the selected vault without presenting legacy Keychain mode as a choice for device-enrolled vaults.
- Consistent command help, examples, `-h`, and help for individual enrollment steps.
- Clearer authentication, status, conflict, interruption, and completed-operation messages.
- Documentation explaining macOS approval, file syncing, backups, and their limits.

Existing configured vaults do not need to run init or migrate. Legacy vault reads, writes, and explicit migration remain supported. No v2 write cutoff or persisted-mode removal is part of this release.

### Recovery stays disabled

Merged recovery implementation is included in the source but is not an enabled 0.3.0 capability. Stable rejects experimental enablement; ordinary Preview leaves it off. The helper must refuse recovery review, registration/adoption, rotation, removal, restore, and resume without creating configuration. Recovery help may describe gated commands; its presence is not a promise that they are available.

The public ZIP verifier rejects an experimental recovery setting other than absent or false in either the host app or helper. Private signed recovery test builds remain separate from public release artifacts. Do not repoint an ordinary 0.3.0 app at an experimental recovery-capable vault. Preserve that vault and its matching private test installation while recovery qualification continues.

Independent backup-token and recovery lifecycle qualification are not prerequisites for this recovery-disabled release. Shared code changes still require ordinary vault regression and installed-product checks. Enabling recovery later requires its own reviewed rollout and the [recovery acceptance gates](piv-recovery-plan.md#remaining-acceptance-matrix).

### Remaining gates

| Gate | Required result | Current evidence / next action |
|---|---|---|
| Source and scope | Release from current main plus reviewed release-preparation changes, with recovery disabled. | Setup PR #67, wording/parser PR #68, recovery layers through #85, and release/CI PR #90 are merged. |
| Automated regression | Full candidate checks pass; focused tests cover any later changes. | PR #90's candidate `2a29f91` passed all nine executed jobs: 1,847 Swift tests passed and one optional qualification case was skipped. This is not a signed-artifact result. |
| Recovery-disabled boundary | Both public products refuse explicit recovery requests; a public ZIP cannot carry the experimental opt-in. | Local release-script tests and 36 focused Swift tests passed on 2026-10-29. Live-host coverage exercises 17 requests in ordinary Stable, ordinary Preview, and Stable with attempted opt-in. ZIP fixtures cover both app/helper plists in both channels, accepting absent/false and rejecting true/invalid settings. Signing services are stubbed in these fixtures. |
| Additional qualification | Debug/Release product checks, the 300-entry migration case, and CodeQL pass on identified source. | On main `031a2c7`, Preview Debug/Release and migration scale passed in [run 40983014889](https://github.com/tvr-works/key/actions/runs/40983014889); CodeQL is still running. Stable qualification was requested in [run 40983538633](https://github.com/tvr-works/key/actions/runs/40983538633). Neither run includes this branch's publication guard. Final-source relevance must also be checked. |
| Fresh installed setup | Signed app registers the correct helper; init verifies a disposable empty vault, preserves existing config, and handles missing parents/nonempty folders safely. | Single-Mac disposable testing authorized on 2026-10-29. The isolated app build stopped before installation because Xcode could not refresh a development profile that excludes the current signing certificate. Repair the Xcode account/profile, then test setup and interruptions without deleting attempt records or forcing another init. |
| Existing users | Upgrade from 0.2.0 preserves legacy local/iCloud key lookup and device-enrolled vault selection; read/edit/lock/reopen and explicit migration remain correct. | The isolated 0.2.0 seed build hit the same signing blocker before installation. The migration runner now prepares legacy data with 0.2.0, upgrades only the qualification app, and verifies retained config/values before migration. The revised installed flow has not yet run end to end. Preview cannot substitute for Stable namespace checks. |
| Two-Mac joining and sync | Compare/approve/accept works from the same synced folder; delayed files, unavailable approval, and restart/retry produce safe guidance without switching vaults. | Pending signed two-Mac and APFS/iCloud qualification. |
| Version and artifact | Reviewed version commit, fresh build number, signatures, entitlements, notarization, Gatekeeper, quarantine, and helper registration all match the exact artifact. | Version PR and signed artifact pending. Main still records build 19, but private Preview artifacts used builds through 25; reserve those numbers and use at least build 26 for the next candidate. Recheck for newer private builds before choosing it. |
| Publication | Publish the verified ZIP/checksum and tag, then explicitly update the organization Homebrew tap and smoke-test distribution. | Pending approval after the earlier gates pass. No tag, release, or tap update is authorized by a test run. |

Do not overwrite or convert a real vault to complete this checklist. Before installed tests, agree on disposable source/destination folders, which product may be installed or replaced, rollback material, and the authentication steps. Keep installed experimental Preview recovery state separate from the ordinary beta. Record source, version/build, platform, outcome, and limitations for each qualification batch here; do not carry a historical pass forward to changed behavior without checking its relevance.

Local release-preparation checks used Xcode 27.1 / Swift 6.4, while hosted qualification pins Xcode 26.4.1 / Swift 6.3.1. Shell syntax, SwiftFormat, SwiftLint, and diff whitespace checks passed for the affected code. These results do not cover signing, installation, native authentication, or physical hardware.

### Single-Mac checkpoint, 2026-10-29

The owner authorized disposable single-Mac checks, preserving the Stable vault, and asked to stop before testing the second Mac. Both attempted qualification builds failed before installation: Xcode reported missing account credentials, and the installed wildcard Mac development profile excludes the currently available Apple Development certificate. The Developer ID certificate remains valid, but its installed profiles name the shipping products and do not authorize these separate qualification identities. No signing requirement or entitlement was removed to bypass the failure.

The focused setup/config/genesis/migration run passed 55 of 59 tests. Four `V2MigrationPreflightTests` failed while preparing fixtures with `Data.write(..., options: .completeFileProtection)`, before migration assertions. A standalone Foundation probe reproduced ordinary writes succeeding and protected writes failing with `NSCocoaErrorDomain 513` / `NSPOSIXErrorDomain 1`, both before and after Developer ID signing. This narrows the failure to local protected-file writes; its cause remains unresolved. The result is not a passing migration gate, and file protection was not weakened.

Before/after snapshots matched all 350 recorded Stable/Preview file hashes and helper-registration checks, including the configured vault folders. Neither product was installed, replaced, launched, locked, or authenticated by this attempt. No YubiKey operation occurred. Local evidence is under `.build/qualification-030-20261029/` (build logs, test output, protected-write probes, and snapshots); these local records are not publication assets. Shell syntax, diff checks, and refusal of the obsolete no-rebuild option passed for the revised runner. Installed setup, legacy local/iCloud upgrades, already-enrolled-vault upgrades, and migration remain unqualified; second-Mac tests have not started.

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
just bump-version <tag>
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
just bump-version "${release_tag}"
```

Replace the example tag with the intended version. A Preview release uses a
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
