import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "ios_store_version_preflight.rb"
)


class IosStoreVersionPreflightTest(unittest.TestCase):
    def run_preflight(
        self,
        payload: dict | list | str,
        candidate_version: str = "1.0.21",
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as file:
            json.dump(payload, file)
            file.flush()
            return subprocess.run(
                ["ruby", str(SCRIPT_PATH), file.name, candidate_version],
                check=False,
                text=True,
                capture_output=True,
            )

    def test_allows_version_above_latest_approved_version(self) -> None:
        result = self.run_preflight(
            {"buildId": "build-id", "version": "1.0.20", "buildNumber": "848"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("newer than approved App Store version 1.0.20", result.stdout)

    def test_blocks_same_version_as_latest_approved_version(self) -> None:
        result = self.run_preflight(
            {"buildId": "build-id", "version": "1.0.20", "buildNumber": "848"},
            candidate_version="1.0.20",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be newer than approved App Store version 1.0.20", result.stderr)

    def test_blocks_version_below_latest_approved_version(self) -> None:
        result = self.run_preflight(
            {"buildId": "build-id", "version": "1.2.0", "buildNumber": "848"},
            candidate_version="1.1.99",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be newer than approved App Store version 1.2.0", result.stderr)

    def test_compares_numeric_components_instead_of_lexically(self) -> None:
        result = self.run_preflight(
            {"buildId": "build-id", "version": "1.9.9", "buildNumber": "848"},
            candidate_version="1.10.0",
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_closed_on_missing_version(self) -> None:
        result = self.run_preflight({"buildId": "build-id", "buildNumber": "848"})

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing version", result.stderr)

    def test_fails_closed_on_invalid_json_shape(self) -> None:
        result = self.run_preflight([])

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected a JSON object", result.stderr)

    def test_fails_closed_on_invalid_version(self) -> None:
        result = self.run_preflight(
            {"buildId": "build-id", "version": "1.0.20", "buildNumber": "848"},
            candidate_version="next",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid candidate version", result.stderr)


if __name__ == "__main__":
    unittest.main()
