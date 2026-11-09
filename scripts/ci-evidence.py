#!/usr/bin/env python3
"""Record same-run CI evidence and decide whether a candidate was verified."""

import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

GROUPS = tuple(json.loads(Path(__file__).with_name("swift-test-groups.json").read_text()))
SCALE_TEST = "migratesRealisticLargeMixedSnapshotWithoutChangingV2Source"
PREVIEW_PATHS = ("Sources/", "Config/", "AppIcon.icon/", "Key.xcodeproj/", "scripts/", "Tests/CLIScripts/",
                 "Tests/ReleaseScripts/", "Tests/PreviewScripts/", ".github/")


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def plan(event_name, event, paths):
    if event_name == "workflow_dispatch":
        return {"full": True, "preview": True, "kind": "manual"}
    if event_name != "pull_request":
        raise ValueError("Unsupported verification event")
    pr = event["pull_request"]
    if type(pr["draft"]) is not bool:
        raise ValueError("Missing Boolean draft state")
    stack = pr.get("stack")
    if stack is not None:
        position, size = stack["position"], stack["size"]
        if type(position) is not int or type(size) is not int or not 1 <= position <= size:
            raise ValueError("Invalid native stack position")
    kind = "standalone" if not stack else ("stack-top" if position == size else "stack-intermediate")
    preview = any(p.startswith(PREVIEW_PATHS) or p in ("Package.swift", "Package.resolved", "completions/_key")
                  for p in paths)
    return {"full": not pr["draft"], "preview": preview, "kind": kind}


def test_results(path):
    reports = sorted(path.parent.glob(path.stem + "*.xml"))
    cases = [case for report in reports for case in ET.parse(report).getroot().findall(".//testcase")]
    if not cases:
        raise ValueError("Missing or empty test reports")
    skipped = [case.get("classname", "") + "/" + case.get("name", "")
               for case in cases if case.find("skipped") is not None]
    failed = sum(case.find("failure") is not None or case.find("error") is not None for case in cases)
    return {"reported": len(cases), "skipped": skipped, "failed": failed}


def record(job, report, steps, environment):
    evidence = {"schema": 1, "job": job, "sha": command("git", "rev-parse", "HEAD"),
                "run_id": environment["GITHUB_RUN_ID"], "attempt": environment["GITHUB_RUN_ATTEMPT"],
                "event": environment["GITHUB_EVENT_NAME"], "status": environment["CI_JOB_STATUS"],
                "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "steps": {name: {key: value[key] for key in ("outcome", "conclusion")}
                          for name, value in steps.items()},
                "dependencies": json.loads(Path("Package.resolved").read_text())["pins"],
                "ci_tools": json.loads(Path(".github/ci-tools.json").read_text()),
                "toolchain": {"os": command("sw_vers", "-productVersion"),
                              "architecture": command("uname", "-m"),
                              "xcode": command("xcodebuild", "-version"),
                              "swift": command("swift", "--version")}}
    if environment.get("CI_CODEQL_VERSION"):
        evidence["toolchain"]["codeql"] = environment["CI_CODEQL_VERSION"]
    if report:
        try:
            evidence["tests"] = test_results(report)
        except (OSError, ET.ParseError, ValueError) as error:
            evidence["test_report_error"] = str(error)
    return evidence


def verify(records, expected, identity):
    """Only evidence for this SHA/run/attempt can satisfy a required job."""
    errors, indexed = [], {}
    for item in records:
        name = item.get("job")
        if name in indexed:
            errors.append(f"Duplicate evidence: {name}")
        indexed[name] = item
        if item.get("schema") != 1 or any(item.get(key) != value for key, value in identity.items()):
            errors.append(f"Wrong evidence identity: {name}")
    if set(indexed) != set(expected):
        errors.append(f"Evidence jobs differ: expected {sorted(expected)}, received {sorted(indexed)}")
    for name, required_steps in expected.items():
        item = indexed.get(name, {})
        if item.get("status") != "success":
            errors.append(f"Job did not succeed: {name}")
        for step in required_steps:
            result = item.get("steps", {}).get(step, {})
            if result.get("outcome") != "success" or result.get("conclusion") != "success":
                errors.append(f"Step did not execute successfully: {name}/{step}")
        if "tests" in required_steps:
            tests = item.get("tests", {})
            count, failed, skipped = tests.get("reported"), tests.get("failed"), tests.get("skipped")
            if type(count) is not int or count <= 0 or failed != 0 or not isinstance(skipped, list):
                errors.append(f"Missing or failing test results: {name}")
            elif len(skipped) >= count or any(SCALE_TEST not in test for test in skipped) or (name == "migration-scale" and skipped):
                errors.append(f"Unexpected skipped tests: {name}")
        if not item.get("toolchain") or not isinstance(item.get("dependencies"), list):
            errors.append(f"Missing toolchain or dependency evidence: {name}")
    return errors


def aggregate(mode, records, needs, selection, identity):
    errors = []
    if mode == "pull-request":
        if not all(type(selection.get(key)) is bool for key in ("full", "preview")):
            raise ValueError("Missing verification selection")
        expected = {f"swift-{group}": ("build", "discovery", "tests", "summary") for group in GROUPS}
        expected["stable-release"] = ("build", "bundle", "cli")
        if selection["preview"]:
            expected["preview-release"] = ("build", "bundle", "cli")
        required = {"plan", "swift-test-suites", "swift-tests", "products", "repository-checks", "workflows", "secrets"}
        if selection["preview"]:
            required.add("preview")
        if not selection["full"]:
            errors.append("Draft candidates are not eligible to merge")
    else:
        expected = {f"{selection['product']}-{configuration}": ("build", "bundle", "cli")
                    for configuration in ("debug", "release")}
        required = {"products"}
        if selection["migration_scale"]:
            expected["migration-scale"] = ("tests",)
            required.add("migration-scale")
        if selection["codeql"]:
            expected["codeql"] = ("build", "analyze")
            required.add("codeql")
    errors += [f"Required job did not succeed: {name}" for name in sorted(required)
               if needs.get(name, {}).get("result") != "success"]
    errors += verify(records, expected, identity)
    return {"schema": 1, **identity, "selection": selection, "jobs": needs, "evidence": records,
            "verified": not errors,
            "merge_eligible": not errors and mode == "pull-request" and identity["event"] == "pull_request",
            "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("plan", "record", "aggregate"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--job")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--mode", choices=("pull-request", "qualification"))
    parser.add_argument("--directory", type=Path)
    args = parser.parse_args()
    env = os.environ
    if args.operation == "plan":
        event = json.loads(Path(env["GITHUB_EVENT_PATH"]).read_text())
        paths = []
        if env["GITHUB_EVENT_NAME"] == "pull_request":
            pr = event["pull_request"]
            base = (pr.get("stack") or {}).get("base", pr["base"])["sha"]
            paths = command("git", "diff", "--name-only", "-z", base + "..." + pr["head"]["sha"]).split("\0")
        result = plan(env["GITHUB_EVENT_NAME"], event, paths)
        with open(env["GITHUB_OUTPUT"], "a") as output:
            output.write("selection=" + json.dumps(result) + "\n")
            for key, value in result.items():
                output.write(f"{key}={str(value).lower()}\n")
    elif args.operation == "record":
        result = record(args.job, args.report, json.loads(env["CI_STEPS"]), env)
    else:
        identity = {"sha": env["GITHUB_SHA"], "run_id": env["GITHUB_RUN_ID"],
                    "attempt": env["GITHUB_RUN_ATTEMPT"], "event": env["GITHUB_EVENT_NAME"]}
        try:
            records = [json.loads(p.read_text()) for p in args.directory.rglob("*.json")]
            result = aggregate(args.mode, records, json.loads(env["CI_NEEDS"]), json.loads(env["CI_SELECTION"]), identity)
        except (KeyError, TypeError, AttributeError, OSError, ValueError) as error:
            result = {"schema": 1, **identity, "verified": False, "merge_eligible": False,
                      "errors": [f"Invalid or incomplete evidence: {error}"]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    if args.operation == "aggregate":
        print(json.dumps({key: result[key] for key in ("verified", "merge_eligible", "errors")}))
        if env.get("GITHUB_STEP_SUMMARY"):
            with open(env["GITHUB_STEP_SUMMARY"], "a") as summary:
                summary.write(f"Verified: {result['verified']}; PR merge eligible: {result['merge_eligible']}\n")
                summary.writelines(f"- {error}\n" for error in result["errors"])
        return 0 if result["verified"] else 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"CI evidence failed: {error}")
