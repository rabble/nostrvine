import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "mobile" / "scripts" / "shorebird_provenance.rb"


class ShorebirdProvenanceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.defines = self.root / "defines.json"
        self.record = self.root / "record.json"
        self.env_output = self.root / "patch.env"
        self.defines.write_text(
            json.dumps({"DEFAULT_ENV": "PRODUCTION", "SECRET_TOKEN": "release-secret"})
        )
        self.head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
        self.environment = {
            **os.environ,
            "SHOREBIRD_PROVENANCE_HMAC_KEY": "test-only-hmac-key-with-32-bytes-minimum",
            "SHOREBIRD_PROVENANCE_HMAC_KEY_ID": "test-key-v1",
        }

    def emit(self, output: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "ruby",
                str(SCRIPT),
                "emit",
                "--platform",
                "ios",
                "--release-version",
                "1.2.3+456",
                "--source-commit",
                self.head,
                "--patch-baseline-commit",
                self.head,
                "--flutter-version",
                "3.44.9",
                "--shorebird-cli-version",
                "Shorebird 1.6.117",
                "--shorebird-cli-revision",
                "45facdd4e4b3c39e0d260107977584f0b7c66bec",
                "--defines",
                str(self.defines),
                "--output",
                str(output or self.record),
            ],
            cwd=REPO_ROOT,
            env=self.environment,
            check=False,
            text=True,
            capture_output=True,
        )

    def verify(
        self,
        environment: dict[str, str] | None = None,
        **overrides: str,
    ) -> subprocess.CompletedProcess[str]:
        arguments = [
            "ruby",
            str(SCRIPT),
            "verify",
            "--platform",
            overrides.get("platform", "ios"),
            "--release-version",
            overrides.get("release_version", "1.2.3+456"),
            "--flutter-version",
            overrides.get("flutter_version", "3.44.9"),
            "--shorebird-cli-version",
            overrides.get("shorebird_cli_version", "Shorebird 1.6.117"),
            "--shorebird-cli-revision",
            overrides.get(
                "shorebird_cli_revision",
                "45facdd4e4b3c39e0d260107977584f0b7c66bec",
            ),
            "--defines",
            str(self.defines),
            "--record",
            str(self.record),
            "--env-output",
            str(self.env_output),
        ]
        if "release_commit" in overrides:
            arguments.extend(["--release-commit", overrides["release_commit"]])
        return subprocess.run(
            arguments,
            cwd=REPO_ROOT,
            env=environment or self.environment,
            check=False,
            text=True,
            capture_output=True,
        )

    def test_fingerprint_is_stable_and_contains_no_values(self) -> None:
        second_record = self.root / "second.json"
        self.assertEqual(0, self.emit().returncode)
        self.assertEqual(0, self.emit(second_record).returncode)
        first = json.loads(self.record.read_text())
        second = json.loads(second_record.read_text())

        self.assertEqual(first["config_fingerprints"], second["config_fingerprints"])
        serialized = self.record.read_text()
        self.assertNotIn("release-secret", serialized)
        self.assertNotIn("PRODUCTION", serialized)

    def test_verify_accepts_matching_record_and_writes_baseline(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        result = self.verify(release_commit=self.head)

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            f"SHOREBIRD_PATCH_BASELINE_COMMIT={self.head}\n",
            self.env_output.read_text(),
        )

    def test_verify_rejects_malformed_or_mismatched_provenance(self) -> None:
        missing = self.verify()
        self.assertNotEqual(0, missing.returncode)
        self.assertIn("release provenance is missing", missing.stderr)

        self.record.write_text("not json")
        malformed = self.verify()
        self.assertNotEqual(0, malformed.returncode)
        self.assertIn("release provenance is malformed", malformed.stderr)

        self.assertEqual(0, self.emit().returncode)
        mismatch = self.verify(release_version="9.9.9+999")
        self.assertNotEqual(0, mismatch.returncode)
        self.assertIn("version does not match", mismatch.stderr)

    def test_verify_rejects_source_override_with_a_different_tree(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        different_commit = subprocess.run(
            ["git", "rev-parse", "HEAD^"],
            cwd=REPO_ROOT,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()

        mismatch = self.verify(release_commit=different_commit)
        self.assertNotEqual(0, mismatch.returncode)
        self.assertIn("does not match the recorded release source", mismatch.stderr)

    def test_verify_rejects_an_authenticated_record_that_was_modified(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record["patch_baseline_commit"] = "0000000000000000000000000000000000000000"
        self.record.write_text(json.dumps(record))

        result = self.verify()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("provenance authentication failed", result.stderr)

    def test_verify_rejects_toolchain_drift(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        flutter_mismatch = self.verify(flutter_version="9.9.9")
        self.assertNotEqual(0, flutter_mismatch.returncode)
        self.assertIn("Flutter version does not match", flutter_mismatch.stderr)

        cli_mismatch = self.verify(
            shorebird_cli_revision="0000000000000000000000000000000000000000"
        )
        self.assertNotEqual(0, cli_mismatch.returncode)
        self.assertIn("CLI revision does not match", cli_mismatch.stderr)

        cli_version_mismatch = self.verify(shorebird_cli_version="Shorebird 9.9.9")
        self.assertNotEqual(0, cli_version_mismatch.returncode)
        self.assertIn("CLI version does not match", cli_version_mismatch.stderr)

    def test_verify_identifies_fingerprint_key_rotation(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        rotated_environment = {
            **self.environment,
            "SHOREBIRD_PROVENANCE_HMAC_KEY_ID": "test-key-v2",
        }
        result = self.verify(environment=rotated_environment)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("different configuration fingerprint key", result.stderr)

    def test_config_drift_reports_only_key_names(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        self.defines.write_text(
            json.dumps({"DEFAULT_ENV": "STAGING", "SECRET_TOKEN": "patch-secret"})
        )
        result = self.verify()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("DEFAULT_ENV", result.stderr)
        self.assertIn("SECRET_TOKEN", result.stderr)
        self.assertNotIn("PRODUCTION", result.stderr)
        self.assertNotIn("STAGING", result.stderr)
        self.assertNotIn("release-secret", result.stderr)
        self.assertNotIn("patch-secret", result.stderr)

    def test_unpatchable_historical_record_fails_closed(self) -> None:
        self.assertEqual(0, self.emit().returncode)
        record = json.loads(self.record.read_text())
        record["patchable"] = False
        record.pop("config_fingerprints")
        self.record.write_text(json.dumps(record))

        result = self.verify()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("verified release configuration is unavailable", result.stderr)


if __name__ == "__main__":
    unittest.main()
