#!/usr/bin/env python3
"""Verify a narrow prose exception and redacted detection of removed secrets."""

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix="key-secret-probe-") as directory:
        work = Path(directory)

        def git(*args):
            subprocess.run(["git", *args], cwd=work, check=True, capture_output=True)

        git("init", "--quiet")
        git("config", "user.name", "Key scanner verification")
        git("config", "user.email", "scanner@example.invalid")
        # Generate a deterministic non-credential, rather than embedding a
        # secret-shaped literal in this repository or contacting a provider.
        marker = hashlib.sha256(b"key scanner synthetic canary").hexdigest()
        sample = work / "Sample.swift"
        sample.write_text(f'let apiKey = "{marker}"\n')
        documents = [work / name for name in (
            "docs/piv-recovery-plan.md", "docs/history/piv-recovery-plan.md")]
        prose = "incorrect current keys,\nmissing/corrupt local records and entry bytes\n"
        for document in documents:
            document.parent.mkdir(parents=True, exist_ok=True)
            document.write_text(prose + f'api_key = "{marker}"\n')
        fixture = work / "Tests/KeyCoreTests/V3LegacyMutationCompatibilityTests.swift"
        fixture.parent.mkdir(parents=True)
        fixture_expression = ": ".join([
            "vaultKey", ".".join(["V3LegacyMutationCompatibilityTests", "vaultKey"])]) + "\n"
        fixture.write_text(fixture_expression + f'api_key = "{marker}"\n')
        diagnostics = [work / "Diagnostics" / name for name in (
            "signature-vector-comparison.swift", "signature-platform-comparison.swift")]
        diagnostics[0].parent.mkdir()
        comparison = '("Public key roundtrip", key.x963Representation == keyBytes)\n'
        for diagnostic in diagnostics:
            diagnostic.write_text(comparison + f'api_key = "{marker}"\n')
        scanner_source = work / "Tests/CIScripts/secret_scanner_probe.py"
        scanner_source.parent.mkdir(parents=True)
        scanner_source.write_text(comparison + f'api_key = "{marker}"\n')
        git("add", ".")
        git("-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Add synthetic canary")
        sample.unlink()
        for document in documents:
            document.write_text(prose)
        fixture.write_text(fixture_expression)
        for diagnostic in diagnostics:
            diagnostic.write_text(comparison)
        scanner_source.write_text(comparison)
        git("add", "-u")
        git("-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Remove synthetic canary")
        report = work / "report.json"
        result = subprocess.run([
            "python3", str(ROOT / "scripts/ci-tool.py"), "run", "gitleaks", "git",
            "--redact=100", "--no-banner", "--config", str(ROOT / ".gitleaks.toml"),
            "--log-opts=--all", "--report-format", "json", "--report-path", str(report), str(work),
        ], capture_output=True, text=True)
        if result.returncode != 1 or not report.exists():
            raise RuntimeError("Scanner did not reject the synthetic commit history")
        findings = json.loads(report.read_text())
        if len(findings) != 7 or {finding["File"] for finding in findings} != {
            "Sample.swift", "docs/piv-recovery-plan.md", "docs/history/piv-recovery-plan.md",
            "Tests/KeyCoreTests/V3LegacyMutationCompatibilityTests.swift",
            "Diagnostics/signature-vector-comparison.swift",
            "Diagnostics/signature-platform-comparison.swift",
            "Tests/CIScripts/secret_scanner_probe.py",
        }:
            raise RuntimeError("Scanner must allow reviewed expressions and detect all removed canaries")
        if marker in report.read_text() or marker in result.stdout or marker in result.stderr:
            raise RuntimeError("Scanner exposed the synthetic secret despite redaction")
        print("Verified narrow prose/expression exceptions, removed-secret detection, and redacted output.")


if __name__ == "__main__":
    main()
