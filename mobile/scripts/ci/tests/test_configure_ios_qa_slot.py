"""Tests for configure_ios_qa_slot.py."""

import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


THIS_DIR = Path(__file__).resolve().parent
SCRIPT_PATH = THIS_DIR.parent / "configure_ios_qa_slot.py"
FIXTURE_DIR = THIS_DIR / "fixtures" / "ios"

SLOT_BUNDLE_ID = "co.openvine.app.qa01"
SLOT_EXT_BUNDLE_ID = "co.openvine.app.qa01.NotificationServiceExtension"
SLOT_APP_GROUP = "group.co.openvine.app.qa01"
SLOT_DISPLAY_NAME = "Divine QA 01"
SLOT_FIREBASE_APP_ID = "1:972941478875:ios:qa01placeholder"


class ConfigureIosQaSlotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ios-qa-slot-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        ios_dst = self.tmp / "ios"
        ios_dst.mkdir(parents=True)
        for src in FIXTURE_DIR.rglob("*"):
            if src.is_file():
                rel = src.relative_to(FIXTURE_DIR)
                dst = ios_dst / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)

    def _run(self, *extra_args, expect_returncode=0):
        cmd = [
            sys.executable,
            str(SCRIPT_PATH),
            "--project-root",
            str(self.tmp),
            "--bundle-id",
            SLOT_BUNDLE_ID,
            "--extension-bundle-id",
            SLOT_EXT_BUNDLE_ID,
            "--app-group",
            SLOT_APP_GROUP,
            "--display-name",
            SLOT_DISPLAY_NAME,
            "--firebase-ios-app-id",
            SLOT_FIREBASE_APP_ID,
            *extra_args,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        self.assertEqual(
            result.returncode,
            expect_returncode,
            msg=(
                f"unexpected returncode={result.returncode}\n"
                f"stdout: {result.stdout}\nstderr: {result.stderr}"
            ),
        )
        return result

    def _pbxproj_text(self):
        return (self.tmp / "ios/Runner.xcodeproj/project.pbxproj").read_text(
            encoding="utf-8",
        )

    def test_patches_main_bundle_id(self):
        self._run()
        text = self._pbxproj_text()
        self.assertIn(f"PRODUCT_BUNDLE_IDENTIFIER = {SLOT_BUNDLE_ID};", text)
        self.assertNotIn("PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app;", text)

    def test_patches_extension_bundle_id(self):
        self._run()
        text = self._pbxproj_text()
        self.assertIn(
            f"PRODUCT_BUNDLE_IDENTIFIER = {SLOT_EXT_BUNDLE_ID};",
            text,
        )
        self.assertNotIn(
            "PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app.NotificationServiceExtension;",
            text,
        )

    def test_does_not_patch_runner_tests_bundle_id(self):
        self._run()
        text = self._pbxproj_text()
        self.assertIn(
            "PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app.RunnerTests;",
            text,
        )
        # Critical: must NOT have produced co.openvine.app.qa01.RunnerTests
        self.assertNotIn(
            f"{SLOT_BUNDLE_ID}.RunnerTests",
            text,
        )

    def test_patches_display_name_with_quotes(self):
        self._run()
        text = self._pbxproj_text()
        self.assertIn(
            f'INFOPLIST_KEY_CFBundleDisplayName = "{SLOT_DISPLAY_NAME}";',
            text,
        )
        self.assertNotIn("INFOPLIST_KEY_CFBundleDisplayName = divine;", text)

    def test_patches_runner_app_group(self):
        self._run()
        path = self.tmp / "ios/Runner/Runner.entitlements"
        with path.open("rb") as fp:
            data = plistlib.load(fp)
        groups = data["com.apple.security.application-groups"]
        self.assertIn(SLOT_APP_GROUP, groups)
        self.assertNotIn("group.co.openvine.app", groups)

    def test_patches_extension_app_group(self):
        self._run()
        path = (
            self.tmp
            / "ios/NotificationServiceExtension/NotificationServiceExtension.entitlements"
        )
        with path.open("rb") as fp:
            data = plistlib.load(fp)
        groups = data["com.apple.security.application-groups"]
        self.assertIn(SLOT_APP_GROUP, groups)
        self.assertNotIn("group.co.openvine.app", groups)

    def test_patches_google_service_info(self):
        self._run()
        path = self.tmp / "ios/Runner/GoogleService-Info.plist"
        with path.open("rb") as fp:
            data = plistlib.load(fp)
        self.assertEqual(data["BUNDLE_ID"], SLOT_BUNDLE_ID)
        self.assertEqual(data["GOOGLE_APP_ID"], SLOT_FIREBASE_APP_ID)

    def test_patches_firebase_app_id_json(self):
        self._run()
        path = self.tmp / "ios/firebase_app_id_file.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["GOOGLE_APP_ID"], SLOT_FIREBASE_APP_ID)

    def test_dry_run_prints_diff_and_leaves_files_unchanged(self):
        before = {
            p.relative_to(self.tmp): p.read_bytes()
            for p in (self.tmp / "ios").rglob("*")
            if p.is_file()
        }
        result = self._run("--dry-run")
        self.assertIn("---", result.stdout)
        self.assertIn("+++", result.stdout)
        self.assertIn(SLOT_BUNDLE_ID, result.stdout)
        self.assertIn(SLOT_FIREBASE_APP_ID, result.stdout)
        after = {
            p.relative_to(self.tmp): p.read_bytes()
            for p in (self.tmp / "ios").rglob("*")
            if p.is_file()
        }
        self.assertEqual(before, after)

    def test_missing_required_arg_fails(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--project-root", str(self.tmp)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_missing_production_marker_in_pbxproj_fails(self):
        # Wipe the marker and confirm script fails fast rather than silently no-op.
        pbx = self.tmp / "ios/Runner.xcodeproj/project.pbxproj"
        pbx.write_text("// empty pbxproj\n", encoding="utf-8")
        self._run(expect_returncode=1)


if __name__ == "__main__":
    unittest.main()
