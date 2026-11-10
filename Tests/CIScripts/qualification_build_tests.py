"""Check qualification build isolation without signing, installation or hardware."""

import os
import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class QualificationBuildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.events = self.work / "events"
        compiler = self.work / "xcodebuild"
        compiler.write_text('''#!/usr/bin/env python3
import json, os, pathlib, plistlib, sys
args = sys.argv[1:]
pathlib.Path(os.environ['QUALIFICATION_TEST_ARGS']).write_text(json.dumps(args))
settings = dict(a.split('=', 1) for a in args if '=' in a)
product = args[args.index('-scheme') + 1]
config = args[args.index('-configuration') + 1]
root = pathlib.Path(args[args.index('-derivedDataPath') + 1]) / 'Build/Products' / config / (product + '.app')
variant = 'preview' if product == 'Key Preview' else 'stable'
helper = 'Key Preview Agent' if variant == 'preview' else 'Key Agent'
for kind, dest in [('APP', root), ('HELPER', root / 'Contents/Helpers' / (helper + '.app'))]:
    source = settings.get('KEY_' + kind + '_INFO_PLIST_FILE')
    info = plistlib.loads(pathlib.Path(source).read_bytes()) if source else {}
    info.update(CFBundleIdentifier=settings['KEY_' + kind + '_BUNDLE_IDENTIFIER'],
        KeyQualificationNamespace=settings['KEY_QUALIFICATION_NAMESPACE'],
        HelperMachServiceName=settings['KEY_HELPER_MACH_SERVICE_NAME'], KeyProductVariant=variant)
    if os.environ.get('QUALIFICATION_TEST_BAD_COMPONENT') == kind:
        info['KeyExperimentalRecoveryEnabled'] = False
    if os.environ.get('QUALIFICATION_TEST_PUBLIC_FLAG_COMPONENT') == kind:
        info['KeyRecoveryEnabled'] = True
    path = dest / 'Contents/Info.plist'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(info))
''')
        compiler.chmod(0o755)
        for name in ("codesign", "osascript", "launchctl", "open"):
            stub = self.work / name
            stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name}" >> "$QUALIFICATION_TEST_EVENTS"\n')
            stub.chmod(0o755)
        fixture_path = f"{self.work}:{os.environ['PATH']}"
        self.environment = dict(os.environ, PATH=fixture_path,
            ZDOTDIR=str(ROOT / "Tests/ScriptFixtures"), KEY_SCRIPT_TEST_PATH=fixture_path,
            QUALIFICATION_TEST_EVENTS=str(self.events), QUALIFICATION_TEST_ARGS=str(self.work / "args"),
            KEY_MIGRATION_QUALIFICATION_NAMESPACE="fixture-" + self.work.name.lower().replace('_', '-'),
            KEY_MIGRATION_QUALIFICATION_DERIVED_DATA_PATH=str(self.work / "build"),
            KEY_MIGRATION_QUALIFICATION_APPLICATIONS_DIR=str(self.work / "Applications"),
            KEY_MIGRATION_QUALIFICATION_INSTALL="0",
            KEY_MIGRATION_QUALIFICATION_PRODUCT="stable", KEY_MIGRATION_QUALIFICATION_RECOVERY="0")

    def run_builder(self):
        return subprocess.run([str(ROOT / "scripts/install-migration-qualification-app.sh")],
            env=self.environment, text=True, capture_output=True, timeout=15)

    def test_build_only_never_stops_installs_or_launches_a_product(self):
        for product, recovery in (("stable", "0"), ("preview", "0"), ("preview", "1")):
            with self.subTest(product=product, recovery=recovery):
                self.events.unlink(missing_ok=True)
                self.environment.update(KEY_MIGRATION_QUALIFICATION_PRODUCT=product,
                    KEY_MIGRATION_QUALIFICATION_RECOVERY=recovery)
                result = self.run_builder()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.events.read_text(), "codesign\n")
                self.assertFalse((self.work / "Applications").exists())
                self.assertIn("Built without installing or launching", result.stdout)
                for info_path in (self.work / "build").rglob("Info.plist"):
                    info = plistlib.loads(info_path.read_bytes())
                    self.assertIs(info["KeyRecoveryEnabled"], False)
                    if info["KeyProductVariant"] == product:
                        self.assertEqual(info.get("KeyExperimentalRecoveryEnabled", False), recovery == "1")

    def test_stable_recovery_and_implicit_namespace_refuse_before_build(self):
        self.environment["KEY_MIGRATION_QUALIFICATION_RECOVERY"] = "1"
        self.assertNotEqual(self.run_builder().returncode, 0)
        self.environment["KEY_MIGRATION_QUALIFICATION_PRODUCT"] = "preview"
        del self.environment["KEY_MIGRATION_QUALIFICATION_NAMESPACE"]
        self.assertNotEqual(self.run_builder().returncode, 0)
        self.assertFalse((self.work / "args").exists())
        self.assertFalse(self.events.exists())

    def test_missing_opt_in_in_either_component_refuses_before_install(self):
        self.environment.update(KEY_MIGRATION_QUALIFICATION_PRODUCT="preview",
            KEY_MIGRATION_QUALIFICATION_RECOVERY="1", KEY_MIGRATION_QUALIFICATION_INSTALL="1")
        for component in ("APP", "HELPER"):
            with self.subTest(component=component):
                self.environment["QUALIFICATION_TEST_BAD_COMPONENT"] = component
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("wrong recovery setting", result.stderr)
                self.assertFalse(self.events.exists())
                self.assertFalse((self.work / "Applications").exists())

    def test_public_flag_cannot_bypass_private_qualification_choice(self):
        self.environment.update(KEY_MIGRATION_QUALIFICATION_PRODUCT="preview",
            KEY_MIGRATION_QUALIFICATION_RECOVERY="0", KEY_MIGRATION_QUALIFICATION_INSTALL="1")
        for component in ("APP", "HELPER"):
            with self.subTest(component=component):
                self.environment["QUALIFICATION_TEST_PUBLIC_FLAG_COMPONENT"] = component
                result = self.run_builder()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("must not inherit public recovery", result.stderr)
                self.assertFalse(self.events.exists())
                self.assertFalse((self.work / "Applications").exists())

    def test_existing_recovery_installation_is_preserved_before_build(self):
        self.environment.update(KEY_MIGRATION_QUALIFICATION_PRODUCT="preview",
            KEY_MIGRATION_QUALIFICATION_RECOVERY="1")
        app = self.work / "Applications" / (
            "Key Preview Migration Qualification " + self.environment["KEY_MIGRATION_QUALIFICATION_NAMESPACE"] + ".app")
        app.mkdir(parents=True)
        marker = app / "keep"
        marker.write_text("previous attempt")
        result = self.run_builder()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fresh identity", result.stderr)
        self.assertEqual(marker.read_text(), "previous attempt")
        self.assertFalse((self.work / "args").exists())
        self.assertFalse(self.events.exists())


if __name__ == "__main__":
    unittest.main()
