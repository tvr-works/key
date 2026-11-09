# Development and verification workflow

Keep stack layers in draft while developing them. Mark a layer ready when its
complete prefix can land. Prepare a Stable or Preview release when there is something to
ship. CI follows those decisions; it has no weekly or monthly schedule.

## Workflows and checks

| Workflow | Trigger | Work |
|---|---|---|
| Verify pull request | PR opened, updated, reopened, marked ready, or converted to draft; also manual | Inexpensive checks on every draft. Every ready standalone PR or stack layer runs the full merge gate; relevant changes also build Preview Release. |
| Verify release candidate | Manual | Debug and Release builds for the selected Stable or Preview product, with optional migration-scale qualification and CodeQL. |
| Verify CodeQL | Manual, or called by release qualification | Swift security analysis on the Intel runner. |

A workflow contains jobs; GitHub shows each job as a check. Formatting, lint,
script fixtures, and dependency checks are steps within **Verify repository
checks**. **Verify workflows** and **Verify secrets** remain separate jobs.
The four Swift test groups run in parallel and feed **Verify Swift tests**.
**Verify merge eligibility** always runs and requires all four executed group
records, the required product checks, and successful repository checks. A draft
gets an explicit failing eligibility result while its inexpensive checks run. **Verify products (Stable Release)** builds the unsigned app,
checks bundle identities and helper isolation, and exercises its bundled CLIs.

The five currently required check names and their GitHub Actions provider are recorded in
[the main ruleset](../.github/main-ruleset.json). Main requires PRs, blocks force
pushes and deletion, and permits squash merges. No external reviewer approval
is mandatory. The maintainer's exception permission applies through PRs only.

## Develop a draft stack

Run relevant local tests while editing. Push draft standalone PRs or update the
layers of a registered stack to get formatting, correctness lint, dependency review,
script checks, workflow audits, and secret scanning. These inexpensive checks do not compile the Swift test suite
or build the app.

Keep each layer draft until its prefix is ready for full verification.
If a ready candidate needs more development, convert it back to draft. That
cancels its superseded PR run and returns it to the inexpensive checks.

## Verify and merge a candidate

Mark a standalone PR or stack layer ready. CI runs all four Swift groups and
the Stable Release product check alongside the inexpensive checks. Changes to
production sources, Xcode/configuration, package declarations or pins, CI and
verification scripts, bundled CLI/release/install tests, or shipped completions
also run one Preview Release product check. Selection uses the complete diff
from the stack trunk, including changes in lower layers. Prose-only changes
avoid the additional Preview build. Manual verification includes Preview. New pushes
to a ready candidate require another pass; an older green result does not
verify changed source.

Keep lower layers draft while reviewing the combined top if desired. Before
merging, mark each layer that will land ready and wait for its own verification.
GitHub evaluates the required checks of every merged layer. Use the native tools
for the atomic merge:

```sh
gh stack merge --yes --squash
```

Each ready layer verifies its prefix, so merging up to an intermediate PR remains
supported. This costs a full verification run per ready layer. A passing top
cannot certify an intermediate prefix: later changes might repair earlier ones.
This avoids copying success between PRs, extra write permissions, and a custom
stack merge service.

A small Stable fix follows the same PR merge gate and can go straight to a
Stable release without a Preview release. There is no automatic post-merge run.

To request the full candidate checks without changing draft status:

```sh
gh workflow run verify.yml --ref <candidate-branch>
```

The PR dependency-advisory comparison runs on PR events, where the stack's trunk
and head are known. A manual run still checks dependency declarations and pins;
it does not replace that PR comparison or satisfy PR required checks. Its manifest
can report successful verification while explicitly reporting `merge_eligible: false`. Manual workflow buttons become available
after their definitions reach the default branch.

## Verification evidence and rollout

Each macOS verification job records the actual checkout SHA, workflow run and
attempt, OS/architecture/Xcode/Swift versions, dependency pins, step outcomes, and
reported test totals with named skips and failure counts. Step outputs and
failure messages are excluded. The aggregate manifest contains selected work,
job outcomes, the job records, verification errors, and a separate PR eligibility
Boolean. Optional qualification jobs remain explicitly skipped when unselected.
This is CI evidence, not a signed artifact attestation or proof of release safety.

The gate rejects failed, missing, duplicate, cancelled, skipped, stale-SHA and
wrong-attempt evidence. Only the named 300-entry scale case may skip in routine
tests; selected migration qualification permits no skips. Rerun all jobs after
a failed run: successful records from an earlier attempt do not satisfy a new
attempt. Cancelled or interrupted workflows may lack a final manifest and never
certify eligibility.

Routine machine-readable evidence is retained for seven days, routine raw reports
for three days, release-qualification records/manifests for 90 days, and product
qualification/CodeQL diagnostics for 14 days. Download the manifest and any needed
reports before expiry when preserving release evidence. Retention does not make
GitHub artifacts permanent.

The checked-in ruleset snapshot and live settings are unchanged by this work.
After the new check passes on a real ready PR, the minimal proposed rule is:

```json
{
  "strict_required_status_checks_policy": true,
  "do_not_enforce_on_create": false,
  "required_status_checks": [
    {"context": "Verify merge eligibility", "integration_id": 15368}
  ]
}
```

First add that check alongside the existing five, validate a ready PR and draft
refusal, then remove the redundant five contexts after review. The new gate
depends on every substantive check, including conditional Preview, so requiring
only this gate retains their enforcement. Strict freshness requires reverifying
after the base changes. Retain the current PR, squash, deletion/force-push and
bypass policy unless separately reviewed. Public repositories support these
rulesets on GitHub Free; no merge queue or paid-plan feature is required.

A new gate in a branch cannot become a required check by itself. Until an
authorized settings update, the five existing contexts remain the enforced
policy. There is no new permission to sign, publish, update Homebrew, or change
repository settings.

References: [stack merge requirements](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests),
[required check semantics](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks),
and [ruleset availability and freshness](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

## Choose additional qualification

Use **Verify release candidate** when the change or release needs the additional
coverage. Select Stable or Preview; it builds and checks that product in both
Debug and Release. This is useful for Preview work, configuration changes, or
release preparation. It does not repeat the full Swift suite.

Include the 300-entry migration qualification when migration, recovery, or
storage behavior changes. Include CodeQL before a Stable release containing
production changes, or when security-sensitive work needs analysis during
development. For example:

```sh
gh workflow run verify-qualification.yml --ref <candidate-branch> \
  -f product=preview -F migration_scale=true -F codeql=true
```

To request only CodeQL:

```sh
gh workflow run verify-codeql.yml --ref <candidate-branch>
```

Review findings, failures, extraction diagnostics, and the source revision
reported by the run. An optional job skipped because it was not selected is not
a passing qualification. CodeQL uses the same pinned extraction steps whether
run independently or through qualification.

These CI product checks are unsigned. Installed-app behavior, signing,
notarization, Gatekeeper, Secure Enclave/user-presence behavior, and real recovery
hardware still need the relevant local qualification. Follow the
[release runbook](release.md) for the distributable artifact.

## Prepare and publish a release

Put the version bump in the candidate before final PR verification. It can be
part of the small fix PR or a final layer on the feature stack. If the change
has already landed, prepare a separate version PR. Merge through the usual gate,
then build and publish from clean main matching the remote version commit.

Stable and Preview are selected by the release tag. Stable tags use `vX.Y.Z`;
Preview tags use numbered `alpha`, `beta`, or `rc` suffixes. The
[release runbook](release.md#operator-runbook) contains the commands and artifact
checks. Publication and the Homebrew update are explicit operator actions.

## Leave the project dormant

There are no scheduled build, test, qualification, or CodeQL runs. Dependabot
alerts continue monitoring the dependency graph independently. Both security
update PRs and version update PRs remain disabled. Existing Action pins are
checked for known advisories when workflow audits next run; no background
workflow audit is scheduled.

Before resuming work or shipping after a long pause, inspect the dependency
alerts and run the candidate checks. Request CodeQL and the applicable release
qualification as part of preparing that release.
