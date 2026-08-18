import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "shorebird_release_preflight.rb"
)


class ShorebirdReleasePreflightTest(unittest.TestCase):
    def run_preflight(
        self,
        payload: dict,
        platform: str = "ios",
        release_version: str = "1.0.20+841",
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as file:
            json.dump(payload, file)
            file.flush()
            return subprocess.run(
                [
                    "ruby",
                    str(SCRIPT_PATH),
                    file.name,
                    platform,
                    release_version,
                ],
                check=False,
                text=True,
                capture_output=True,
            )

    def test_allows_missing_release(self) -> None:
        result = self.run_preflight(
            {
                "status": "success",
                "data": {
                    "releases": [
                        {
                            "version": "1.0.20+840",
                            "platform_statuses": {"ios": "active"},
                        }
                    ]
                },
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("No existing Shorebird ios release", result.stdout)

    def test_blocks_active_platform_release(self) -> None:
        result = self.run_preflight(
            {
                "status": "success",
                "data": {
                    "releases": [
                        {
                            "version": "1.0.20+841",
                            "platform_statuses": {"ios": "active"},
                        }
                    ]
                },
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists with status active", result.stderr)

    def test_blocks_non_active_platform_release(self) -> None:
        result = self.run_preflight(
            {
                "status": "success",
                "data": {
                    "releases": [
                        {
                            "version": "1.0.20+841",
                            "platform_statuses": {"ios": "failed"},
                        }
                    ]
                },
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists with status failed", result.stderr)

    def test_allows_same_version_for_different_platform(self) -> None:
        result = self.run_preflight(
            {
                "status": "success",
                "data": {
                    "releases": [
                        {
                            "version": "1.0.20+841",
                            "platform_statuses": {"android": "active"},
                        }
                    ]
                },
            },
            platform="ios",
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_closed_on_error_envelope(self) -> None:
        result = self.run_preflight(
            {
                "status": "error",
                "error": {
                    "code": "fetch_failed",
                    "message": "Insufficient permissions.",
                },
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fetch_failed", result.stderr)
        self.assertIn("Insufficient permissions", result.stderr)

    def test_fails_closed_on_unexpected_shape(self) -> None:
        result = self.run_preflight({"status": "success", "data": {}})

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing releases array", result.stderr)

    def test_fails_closed_on_unreadable_platform_statuses(self) -> None:
        result = self.run_preflight(
            {
                "status": "success",
                "data": {
                    "releases": [
                        {
                            "version": "1.0.20+841",
                            "platform_statuses": ["ios", "active"],
                        }
                    ]
                },
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unreadable platform_statuses", result.stderr)


if __name__ == "__main__":
    unittest.main()
