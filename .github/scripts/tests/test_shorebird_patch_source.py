import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "mobile" / "scripts" / "shorebird_patch_source.rb"


class ShorebirdPatchSourceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(
            ["git", "config", "user.email", "shorebird-test@example.invalid"],
            cwd=self.root,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Shorebird Test"],
            cwd=self.root,
            check=True,
        )
        self._commit("lib/release.dart", "const release = true;\n", "release")
        self.baseline = self._git("rev-parse", "HEAD")

    def _git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()

    def _commit(self, relative_path: str, contents: str, message: str) -> str:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        self._git("add", relative_path)
        self._git("commit", "-m", message)
        return self._git("rev-parse", "HEAD")

    def _run(
        self,
        *,
        baseline: str | None = None,
        platform: str = "ios",
        release_version: str = "1.2.3+456",
        branch: str = "shorebird-patch/ios/1.2.3+456",
        cwd: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "ruby",
                str(SCRIPT),
                "--baseline",
                baseline or self.baseline,
                "--platform",
                platform,
                "--release-version",
                release_version,
                "--branch",
                branch,
            ],
            cwd=cwd or self.root,
            check=False,
            text=True,
            capture_output=True,
        )

    def test_accepts_matching_release_branch_with_dart_fix(self) -> None:
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Verified patch branch", result.stdout)
        self.assertIn("lib/fix.dart", result.stdout)

    def test_rejects_main_and_another_release_or_platform(self) -> None:
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        for branch in (
            "main",
            "shorebird-patch/ios/1.2.3+457",
            "shorebird-patch/android/1.2.3+456",
        ):
            with self.subTest(branch=branch):
                result = self._run(branch=branch)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("patch branch must be exactly", result.stderr)

    def test_rejects_release_version_that_is_unsafe_in_a_refspec(self) -> None:
        result = self._run(
            release_version="1.2.3:malicious",
            branch="shorebird-patch/ios/1.2.3:malicious",
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("unsafe in a branch name", result.stderr)

    def test_rejects_history_not_descended_from_release(self) -> None:
        main_branch = self._git("branch", "--show-current")
        self._git("checkout", "--orphan", "unrelated-root")
        self._git("rm", "-rf", "--quiet", ".")
        self._commit("UNRELATED.md", "unrelated\n", "unrelated root")
        unrelated = self._git("rev-parse", "HEAD")
        self._git("checkout", main_branch)

        result = self._run(baseline=unrelated)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("not an ancestor", result.stderr)

    def test_rejects_blocked_paths(self) -> None:
        blocked_paths = (
            "android/app/build.gradle",
            "ios/Runner/AppDelegate.swift",
            "assets/icon.png",
            "pubspec.yaml",
            "scripts/deploy.sh",
            "packages/divine_ui/ios/plugin.swift",
            "packages/divine_ui/pubspec.yaml",
        )
        for index, blocked_path in enumerate(blocked_paths):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"blocked {index}\n", "blocked")
                self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

                result = self._run()

                self.assertNotEqual(0, result.returncode)
                self.assertIn(blocked_path, result.stderr)

    def test_rejects_blocked_paths_under_mobile_directory(self) -> None:
        # Mirrors the real layout and Codemagic's working_directory: the app
        # lives under mobile/, and git diff --name-only still prints
        # repository-root-relative paths.
        mobile = self.root / "mobile"
        for index, blocked_path in enumerate(
            ("mobile/ios/Runner/AppDelegate.swift", "mobile/scripts/deploy.sh")
        ):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"blocked {index}\n", "blocked")
                self._commit("mobile/lib/fix.dart", "const fixed = true;\n", "fix")

                for cwd in (self.root, mobile):
                    with self.subTest(cwd=cwd):
                        result = self._run(cwd=cwd)
                        self.assertNotEqual(0, result.returncode)
                        self.assertIn(
                            blocked_path.removeprefix("mobile/"), result.stderr
                        )

    def test_accepts_dart_fix_from_mobile_working_directory(self) -> None:
        self._commit("mobile/lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run(cwd=self.root / "mobile")

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("lib/fix.dart", result.stdout)

    def test_rejects_empty_dart_diff(self) -> None:
        self._commit("README.md", "documentation only\n", "docs")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("no Dart changes", result.stderr)

    def test_rejects_merge_commits(self) -> None:
        self._git("checkout", "-b", "side")
        self._commit("lib/side.dart", "const side = true;\n", "side")
        self._git("checkout", "-b", "patch-line", self.baseline)
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")
        self._git("merge", "--no-ff", "side", "-m", "merge side")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("contains merge commits", result.stderr)

    def test_second_patch_reports_both_cumulative_fixes(self) -> None:
        self._commit("lib/first_fix.dart", "const first = true;\n", "first fix")
        self._commit("lib/second_fix.dart", "const second = true;\n", "second fix")

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("lib/first_fix.dart", result.stdout)
        self.assertIn("lib/second_fix.dart", result.stdout)


if __name__ == "__main__":
    unittest.main()
