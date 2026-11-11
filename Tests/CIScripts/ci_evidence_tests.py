"""Exercise candidate selection and the evidence protocol at failure boundaries."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ci_evidence", ROOT / "scripts/ci-evidence.py")
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)
IDENTITY = {"sha": "a" * 40, "run_id": "123", "attempt": "2", "event": "pull_request"}
GROUPS = ("core-content", "recovery-lifecycle", "recovery-coordination", "recovery-restore")


def event(draft=False, position=None):
    pr = {"draft": draft, "base": {"sha": "b" * 40}, "head": {"sha": "a" * 40}}
    if position:
        pr["stack"] = {"position": position, "size": 3, "base": {"sha": "c" * 40}}
    return {"pull_request": pr}


def evidence(name, steps, tests=False):
    result = {"schema": 1, **IDENTITY, "job": name, "status": "success",
              "toolchain": {"xcode": "Xcode 26.4.1", "swift": "Swift 6.3.1"},
              "dependencies": [], "steps": {step: {"outcome": "success", "conclusion": "success"}
                                             for step in steps}}
    if tests:
        result["tests"] = {"reported": 3, "skipped": [], "failed": 0}
    return result


class CandidateVerificationTests(unittest.TestCase):
    def setUp(self):
        self.selection = {"full": True, "preview": False, "kind": "standalone"}
        self.records = [evidence("swift-" + group, ("build", "discovery", "tests", "summary"), True)
                        for group in GROUPS]
        self.records.append(evidence("stable-release", ("build", "bundle", "cli")))
        self.needs = {name: {"result": "success"} for name in
                      ("plan", "swift-test-suites", "swift-tests", "products", "repository-checks", "workflows", "secrets")}
        self.needs["preview"] = {"result": "skipped"}

    def aggregate(self):
        return ci.aggregate("pull-request", self.records, self.needs, self.selection, IDENTITY)

    def test_each_ready_native_stack_prefix_is_verified_and_drafts_are_ineligible(self):
        for position in (None, 1, 2, 3):
            with self.subTest(position=position):
                self.selection = ci.plan("pull_request", event(position=position), ["README.md"])
                self.assertTrue(self.aggregate()["merge_eligible"])
                self.selection = ci.plan("pull_request", event(draft=True, position=position), [])
                self.assertFalse(self.aggregate()["merge_eligible"])

    def test_missing_failed_cancelled_skipped_or_empty_shard_blocks_merge(self):
        original = copy.deepcopy(self.records)
        for result in ("failure", "cancelled", "skipped", ""):
            with self.subTest(result=result):
                self.records = copy.deepcopy(original)
                self.records[0]["status"] = result
                self.assertFalse(self.aggregate()["verified"])
        self.records = original[1:]
        self.assertFalse(self.aggregate()["verified"])
        self.records = original + [copy.deepcopy(original[0])]
        self.assertFalse(self.aggregate()["verified"])

    def test_a_successful_matrix_result_cannot_hide_a_missing_or_failed_shard(self):
        self.records[0]["steps"]["tests"] = {"outcome": "failure", "conclusion": "success"}
        self.assertFalse(self.aggregate()["verified"])
        self.records[0]["steps"]["tests"] = {"outcome": "skipped", "conclusion": "skipped"}
        self.assertFalse(self.aggregate()["verified"])

    def test_stale_revision_run_attempt_and_schema_are_rejected(self):
        for field, value in (("sha", "b" * 40), ("run_id", "122"), ("attempt", "1"),
                             ("event", "workflow_dispatch"), ("schema", 2)):
            with self.subTest(field=field):
                old = self.records[0][field]
                self.records[0][field] = value
                self.assertFalse(self.aggregate()["verified"])
                self.records[0][field] = old

    def test_only_the_named_optional_scale_skip_is_accepted(self):
        tests = self.records[0]["tests"]
        tests["skipped"] = [ci.SCALE_CASE]
        self.assertTrue(self.aggregate()["verified"])
        for replacement in (["Other/silentlyDisabled"], [ci.SCALE_CASE] * 2,
                            ["Other/" + ci.SCALE_TEST + "()"], [ci.SCALE_CASE + "Extra"]):
            tests["skipped"] = replacement
            self.assertFalse(self.aggregate()["verified"])
        tests["skipped"] = []
        tests["failed"] = 1
        self.assertFalse(self.aggregate()["verified"])
        del self.records[0]["tests"]
        self.assertFalse(self.aggregate()["verified"])

    def test_all_repository_jobs_must_execute_successfully(self):
        for name in self.needs:
            if name == "preview":
                continue
            for status in ("failure", "cancelled", "skipped"):
                with self.subTest(name=name, status=status):
                    self.needs[name]["result"] = status
                    self.assertFalse(self.aggregate()["verified"])
            self.needs[name]["result"] = "success"

    def test_preview_is_required_only_for_relevant_candidate_paths(self):
        for path in ("Sources/KeyCore/KeyProductIdentity.swift", "Config/Key-Info.plist",
                     "AppIcon.icon/icon.json", "AppIcon.icon/Assets/Shape 2.png",
                     "Key.xcodeproj/project.pbxproj", "Package.resolved", "scripts/verify-product.sh",
                     "Tests/CLIScripts/help-tests.sh", "Tests/ScriptFixtures/completion-manifest.json",
                     ".github/workflows/verify.yml", "completions/_key"):
            with self.subTest(path=path):
                self.selection = ci.plan("pull_request", event(), [path])
                self.assertFalse(self.aggregate()["verified"])
        self.records.append(evidence("preview-release", ("build", "bundle", "cli")))
        self.needs["preview"]["result"] = "success"
        self.assertTrue(self.aggregate()["verified"])
        self.assertFalse(ci.plan("pull_request", event(), ["docs/recovery-user-guide.md"])["preview"])

    def test_manual_full_verification_is_not_a_pr_merge_authorization(self):
        self.selection = ci.plan("workflow_dispatch", {}, [])
        self.records.append(evidence("preview-release", ("build", "bundle", "cli")))
        self.needs["preview"]["result"] = "success"
        identity = dict(IDENTITY, event="workflow_dispatch")
        for record in self.records:
            record["event"] = "workflow_dispatch"
        result = ci.aggregate("pull-request", self.records, self.needs, self.selection, identity)
        self.assertTrue(result["verified"])
        self.assertFalse(result["merge_eligible"])

    def test_invalid_stack_metadata_fails_closed(self):
        for position in (0, 4, "1", True):
            payload = event(position=1)
            payload["pull_request"]["stack"]["position"] = position
            with self.assertRaises(ValueError):
                ci.plan("pull_request", payload, [])


class QualificationProtocolTests(unittest.TestCase):
    def test_optional_jobs_are_explicit_and_selected_jobs_cannot_skip(self):
        selection = {"product": "preview", "migration_scale": False, "codeql": False}
        records = [evidence("preview-" + mode, ("build", "bundle", "cli")) for mode in ("debug", "release")]
        needs = {"products": {"result": "success"}, "migration-scale": {"result": "skipped"},
                 "codeql": {"result": "skipped"}}
        def result():
            return ci.aggregate("qualification", records, needs, selection, IDENTITY)
        self.assertTrue(result()["verified"])
        self.assertFalse(result()["merge_eligible"])
        for option, job, steps in (("migration_scale", "migration-scale", ("tests",)),
                                   ("codeql", "codeql", ("build", "analyze"))):
            selection[option] = True
            self.assertFalse(result()["verified"])
            records.append(evidence(job, steps, job == "migration-scale"))
            needs[job]["result"] = "success"
            self.assertTrue(result()["verified"])
        records[-2]["tests"]["skipped"] = [ci.SCALE_CASE]
        self.assertFalse(result()["verified"])

    def test_real_xunit_reports_preserve_counts_and_skip_names(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tests.xml"
            path.with_name("tests-swift-testing.xml").write_text(
                '<testsuites><testsuite><testcase name="roundTrip"/>'
                '<testcase classname="Genesis" name="scale"><skipped/></testcase>'
                '<testcase name="bad"><failure>do not include sensitive diagnostics</failure></testcase>'
                '</testsuite></testsuites>')
            self.assertEqual(ci.test_results(path), {"reported": 3, "skipped": ["Genesis/scale"], "failed": 1})

    def test_record_cli_captures_toolchain_and_tests_without_step_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "-c", "user.name=CI", "-c", "user.email=ci@example.invalid",
                            "commit", "--allow-empty", "-qm", "fixture"], cwd=root, check=True)
            (root / "Package.resolved").write_text('{"pins": []}')
            (root / ".github").mkdir()
            (root / ".github/ci-tools.json").write_text('{"linter": {"version": "1"}}')
            binary = root / "bin"
            binary.mkdir()
            for name, version in (("xcodebuild", "Xcode 26.4.1"), ("swift", "Swift 6.3.1"),
                                  ("sw_vers", "26.0")):
                tool = binary / name
                tool.write_text('#!/bin/sh\nprintf "%s\\n" "' + version + '"\n')
                tool.chmod(0o755)
            (root / "tests.xml").write_text('<testsuite><testcase name="roundTrip"/></testsuite>')
            steps = {"tests": {"outcome": "success", "conclusion": "success",
                               "outputs": {"private": "must not appear"}}}
            env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                       GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="2", GITHUB_EVENT_NAME="workflow_dispatch",
                       CI_JOB_STATUS="success", CI_STEPS=json.dumps(steps), CI_CODEQL_VERSION="2.27.3")
            subprocess.run([sys.executable, str(ROOT / "scripts/ci-evidence.py"), "record", "--job", "fixture",
                            "--report", str(root / "tests.xml"), "--output", str(root / "record.json")],
                           cwd=root, env=env, check=True)
            text = (root / "record.json").read_text()
            actual = json.loads(text)
            self.assertEqual(actual["toolchain"]["xcode"], "Xcode 26.4.1")
            self.assertEqual(actual["toolchain"]["codeql"], "2.27.3")
            self.assertEqual(actual["tests"]["reported"], 1)
            self.assertEqual(actual["sha"], subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip())
            self.assertNotIn("must not appear", text)

    def test_malformed_aggregate_cli_retains_a_failed_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "broken.json").write_text("not json")
            env = dict(os.environ, GITHUB_SHA=IDENTITY["sha"], GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="2",
                       GITHUB_EVENT_NAME="pull_request", CI_NEEDS="{}", CI_SELECTION="{}")
            result = subprocess.run([sys.executable, str(ROOT / "scripts/ci-evidence.py"), "aggregate",
                                     "--mode", "pull-request", "--directory", str(root),
                                     "--output", str(root / "manifest.json")], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            manifest = json.loads((root / "manifest.json").read_text())
            self.assertFalse(manifest["verified"])
            self.assertFalse(manifest["merge_eligible"])

    def test_plan_cli_uses_the_stack_trunk_diff_and_handles_renames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True).strip()
            git("init", "-q")
            git("config", "user.name", "CI fixture")
            git("config", "user.email", "ci@example.invalid")
            (root / "Config").mkdir()
            (root / "Config/settings").write_text("old")
            git("add", ".")
            git("commit", "-qm", "trunk")
            trunk = git("rev-parse", "HEAD")
            (root / "Unshipped").mkdir()
            git("mv", "Config/settings", "Unshipped/renamed")
            git("commit", "-qm", "lower layer")
            parent = git("rev-parse", "HEAD")
            (root / "README.md").write_text("top-only prose")
            git("add", ".")
            git("commit", "-qm", "top")
            payload = event(position=3)
            payload["pull_request"]["base"]["sha"] = parent
            payload["pull_request"]["head"]["sha"] = git("rev-parse", "HEAD")
            payload["pull_request"]["stack"]["base"]["sha"] = trunk
            event_path = root / "event.json"
            event_path.write_text(json.dumps(payload))
            output = root / "output"
            environment = dict(os.environ, GITHUB_EVENT_NAME="pull_request", GITHUB_EVENT_PATH=str(event_path),
                               GITHUB_OUTPUT=str(output))
            subprocess.run([sys.executable, str(ROOT / "scripts/ci-evidence.py"), "plan", "--output", str(root / "plan.json")],
                           env=environment, cwd=root, check=True)
            self.assertTrue(json.loads((root / "plan.json").read_text())["preview"])
            self.assertIn("full=true", output.read_text())


if __name__ == "__main__":
    unittest.main()
