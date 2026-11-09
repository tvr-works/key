"""Check workflow wiring while behavioral evidence tests own merge decisions."""

import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StackVerificationPolicyTests(unittest.TestCase):
    def jobs(self, filename="verify.yml"):
        workflow = (ROOT / ".github/workflows" / filename).read_text()
        blocks = re.split(r"(?=^  [\w-]+:\n)", workflow.split("jobs:\n", 1)[1],
                          flags=re.MULTILINE)
        return {block.split(":", 1)[0].strip(): block for block in blocks if block.strip()}

    def test_merge_gate_always_observes_every_required_job(self):
        jobs = self.jobs()
        gate = jobs["evidence"]
        self.assertIn("    if: always()", gate)
        dependency_line = re.search(r"^    needs: \[(.+)\]$", gate, re.MULTILINE)[1]
        self.assertEqual(set(dependency_line.split(", ")), set(jobs) - {"evidence"})
        for name in ("swift-test-suites", "products", "preview"):
            self.assertIn("    needs: plan", jobs[name])
            self.assertIn("needs.plan.outputs.full == 'true'", jobs[name])
        for name in ("repository-checks", "workflows", "secrets"):
            self.assertNotRegex(jobs[name], re.compile(r"^    if:", re.MULTILINE))
        self.assertIn("needs.plan.outputs.preview == 'true'", jobs["preview"])
        self.assertIn("if: always() &&", jobs["swift-tests"])
        self.assertIn('run: test "$GROUP_RESULT" = success', jobs["swift-tests"])

    def test_workflows_use_only_the_agreed_pr_and_manual_triggers(self):
        expected = {
            "verify.yml": {"pull_request", "workflow_dispatch"},
            "verify-qualification.yml": {"workflow_dispatch"},
            "verify-codeql.yml": {"workflow_dispatch", "workflow_call"},
        }
        for filename, events in expected.items():
            text = (ROOT / ".github/workflows" / filename).read_text()
            triggers = text.split("on:\n", 1)[1].split("\npermissions:", 1)[0]
            self.assertEqual(set(re.findall(r"^  ([\w_]+):", triggers, re.MULTILINE)), events)
        codeql = self.jobs("verify-codeql.yml")["static-analysis"]
        self.assertIn("    runs-on: macos-26-intel", codeql)
        self.assertIn("      security-events: write", codeql)
        self.assertIn("          queries: security-extended", codeql)
        qualification = self.jobs("verify-qualification.yml")
        self.assertIn("    if: inputs.migration_scale", qualification["migration-scale"])
        self.assertIn("    if: inputs.codeql", qualification["codeql"])
        self.assertIn("uses: ./.github/workflows/verify-codeql.yml", qualification["codeql"])
        self.assertIn("      security-events: write", qualification["codeql"])
        self.assertIn("VARIANT: ${{ inputs.product }}", qualification["products"])
        self.assertIn("            mode: debug", qualification["products"])
        self.assertIn("            mode: release", qualification["products"])

    def test_required_merge_checks_have_stable_non_matrix_job_names(self):
        policy = json.loads((ROOT / ".github/main-ruleset.json").read_text())
        rule = next(rule for rule in policy["rules"]
                    if rule["type"] == "required_status_checks")
        checks = rule["parameters"]["required_status_checks"]
        self.assertTrue(checks)
        workflow = (ROOT / ".github/workflows/verify.yml").read_text()
        jobs = {}
        for block in re.split(r"(?=^  [\w-]+:\n)", workflow.split("jobs:\n", 1)[1],
                              flags=re.MULTILINE):
            name = re.search(r"^    name: (.+)$", block, re.MULTILINE)
            if name:
                jobs[name[1]] = block
        for check in checks:
            # Skipped matrices keep unresolved names; running matrices append
            # their values. Required gates need fixed, non-matrix job names.
            self.assertIn(check["context"], jobs)
            self.assertNotRegex(jobs[check["context"]], re.compile(r"^      matrix:", re.MULTILINE))
            self.assertEqual(check["integration_id"], 15368)
            for filename in ("verify-qualification.yml", "verify-codeql.yml"):
                for block in self.jobs(filename).values():
                    self.assertNotIn(f"    name: {check['context']}\n", block)

    def test_main_ruleset_requires_prs_and_limits_exception_scope(self):
        policy = json.loads((ROOT / ".github/main-ruleset.json").read_text())
        self.assertEqual(policy["enforcement"], "active")
        self.assertEqual(policy["conditions"]["ref_name"],
                         {"include": ["refs/heads/main"], "exclude": []})
        rules = {rule["type"]: rule for rule in policy["rules"]}
        self.assertTrue({"pull_request", "required_status_checks", "deletion",
                         "non_fast_forward"} <= rules.keys())
        self.assertEqual(rules["pull_request"]["parameters"]["allowed_merge_methods"],
                         ["squash"])
        self.assertEqual(rules["pull_request"]["parameters"]["required_approving_review_count"], 0)
        self.assertTrue(all(actor["bypass_mode"] == "pull_request"
                            for actor in policy["bypass_actors"]))

    def test_patch_checks_and_dependency_review_use_the_stack_trunk(self):
        workflow = (ROOT / ".github/workflows/verify.yml").read_text()
        base = "${{ github.event.pull_request.stack.base.sha || github.event.pull_request.base.sha }}"
        self.assertEqual(workflow.count(f"PR_BASE: {base}"), 2)
        self.assertIn(f"base-ref: {base}", workflow)
        self.assertIn("head-ref: ${{ github.event.pull_request.head.sha }}", workflow)


if __name__ == "__main__":
    unittest.main()
