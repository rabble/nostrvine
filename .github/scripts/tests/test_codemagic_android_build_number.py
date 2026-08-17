import re
import subprocess
import unittest
from pathlib import Path


CODEMAGIC_PATH = Path(__file__).resolve().parents[3] / "codemagic.yaml"
MISE_PATH = Path(__file__).resolve().parents[3] / "mobile" / "mise.toml"
MOBILE_CI_PATH = (
    Path(__file__).resolve().parents[3] / ".github" / "workflows" / "mobile_ci.yaml"
)
WORKFLOWS_PATH = Path(__file__).resolve().parents[2] / "workflows"


class CodemagicAndroidBuildNumberTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contents = CODEMAGIC_PATH.read_text()
        self.mobile_ci_contents = MOBILE_CI_PATH.read_text()
        self.mise_contents = MISE_PATH.read_text()

    def test_codemagic_yaml_parses_with_aliases(self) -> None:
        result = subprocess.run(
            [
                "ruby",
                "-e",
                (
                    "require 'yaml'; "
                    "data = YAML.safe_load(File.read(ARGV[0]), aliases: true); "
                    "abort 'missing workflows' unless data.fetch('workflows').is_a?(Hash); "
                    "abort 'missing definitions' unless data.fetch('definitions').is_a?(Hash)"
                ),
                str(CODEMAGIC_PATH),
            ],
            check=False,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_android_aab_build_uses_google_play_floor(self) -> None:
        self.assertIn(
            'google-play get-latest-build-number --package-name "co.openvine.app"',
            self.contents,
        )
        self.assertIn("BUILD_NUMBER=$PROJECT_BUILD_NUMBER", self.contents)
        self.assertIn(
            'NEXT_PLAY_BUILD_NUMBER=$((LATEST_GOOGLE_PLAY_BUILD_NUMBER + 1))',
            self.contents,
        )
        self.assertIn(
            'if [ "$NEXT_PLAY_BUILD_NUMBER" -gt "$BUILD_NUMBER" ]; then',
            self.contents,
        )
        self.assertNotIn("PROJECT_BUILD_NUMBER + 8", self.contents)

    def test_shorebird_supporters_defines_are_optional(self) -> None:
        self.assertIn("optional_names = %w[", self.contents)
        self.assertIn("SUPPORTERS_API_BASE_URL", self.contents)
        self.assertIn("FF_DIVINE_SUPPORTERS", self.contents)
        self.assertIn("defines[name] = ENV.fetch(name, '')", self.contents)

    def test_shorebird_release_commands_are_signed_and_preflighted(self) -> None:
        self.assertIn("*preflight_shorebird_ios_release", self.contents)
        self.assertIn("*preflight_shorebird_android_release", self.contents)
        self.assertIn("shorebird releases list --platform=android --json", self.contents)
        self.assertIn("shorebird releases list --platform=ios --json", self.contents)
        self.assertIn("shorebird_release_preflight.rb", self.contents)
        self.assertNotIn("shorebird releases info", self.contents)
        self.assertIn("--build-name=$BUILD_NAME", self.contents)
        self.assertIn("--public-key-path=build/shorebird/patch_public_key.pem", self.contents)

    def test_flutter_pins_match_current_shorebird_engine(self) -> None:
        mise_version = re.search(r'^flutter = "([^"]+)"$', self.mise_contents, re.MULTILINE)
        self.assertIsNotNone(mise_version)
        expected = mise_version.group(1)

        mobile_ci_versions = set(
            re.findall(r'flutter-version: "([^"]+)"', self.mobile_ci_contents)
        )
        codemagic_flutter_versions = set(
            re.findall(r"^\s+flutter: ([0-9]+\.[0-9]+\.[0-9]+)$", self.contents, re.MULTILINE)
        )
        shorebird_release_versions = set(
            re.findall(r"^\s+FLUTTER_VERSION: ([0-9]+\.[0-9]+\.[0-9]+)$", self.contents, re.MULTILINE)
        )

        self.assertEqual({expected}, mobile_ci_versions)
        self.assertEqual({expected}, codemagic_flutter_versions)
        self.assertEqual({expected}, shorebird_release_versions)
        stale_workflows = []
        for workflow in WORKFLOWS_PATH.glob("*.y*ml"):
            versions = re.findall(
                r"flutter(?:-|_)version:\s*[\"']?([^\"'\s]+)",
                workflow.read_text(),
            )
            if any(version != expected for version in versions):
                stale_workflows.append(workflow.name)
        self.assertEqual([], stale_workflows)

    def test_shorebird_patch_commands_publish_to_staging_and_are_signed(self) -> None:
        self.assertIn(
            "shorebird patch android --release-version=${{ inputs.RELEASE_VERSION }} --track=staging",
            self.contents,
        )
        self.assertIn(
            "shorebird patch ios --release-version=${{ inputs.RELEASE_VERSION }} --track=staging",
            self.contents,
        )
        self.assertIn("--private-key-path=build/shorebird/patch_private_key.pem", self.contents)
        self.assertNotIn("--track=stable", self.contents)

    def test_shorebird_patch_workflows_gate_branch_and_release_commit(self) -> None:
        self.assertIn('if [ "$CM_BRANCH" != "main" ]; then', self.contents)
        self.assertIn("RELEASE_COMMIT:", self.contents)
        self.assertIn("git merge-base --is-ancestor", self.contents)
        self.assertIn("git diff --name-only", self.contents)
        self.assertIn("*prepare_patch_source", self.contents)

    def test_shorebird_patch_workflows_block_native_asset_and_dependency_changes(self) -> None:
        self.assertIn("BLOCKED_PATCH_PATHS=$(git diff --name-only", self.contents)
        self.assertIn("'android/**'", self.contents)
        self.assertIn("'ios/**'", self.contents)
        self.assertIn("'assets/**'", self.contents)
        self.assertIn("'pubspec.yaml'", self.contents)
        self.assertIn("'pubspec.lock'", self.contents)
        self.assertIn("'packages/**/android/**'", self.contents)
        self.assertIn("'packages/**/assets/**'", self.contents)
        self.assertIn("'packages/**/darwin/**'", self.contents)
        self.assertIn("Cut a normal store release instead of a Shorebird patch.", self.contents)
        for command in self._shorebird_patch_commands():
            self.assertNotRegex(command, r"--allow-native-diffs|--allow-asset-diffs")

    def test_store_artifacts_are_built_by_shorebird_release(self) -> None:
        self.assertIn("*build_aab", self._workflow_block("android-build"))
        self.assertIn("*build_ios", self._workflow_block("ios-build"))
        self.assertRegex(self.contents, r"(?m)^\s+shorebird release android ")
        self.assertRegex(self.contents, r"(?m)^\s+shorebird release ios ")
        self.assertNotRegex(self.contents, r"(?m)^\s+flutter build appbundle ")
        self.assertNotRegex(self.contents, r"(?m)^\s+flutter build ipa ")

    def test_release_jobs_never_materialize_patch_private_key(self) -> None:
        self.assertIn("*write_shorebird_public_key", self._workflow_block("ios-build"))
        self.assertIn("*write_shorebird_public_key", self._workflow_block("android-build"))
        self.assertNotIn("*write_shorebird_private_key", self._workflow_block("ios-build"))
        self.assertNotIn("*write_shorebird_private_key", self._workflow_block("android-build"))

    def test_shorebird_cache_is_enabled_for_release_and_patch_workflows(self) -> None:
        for workflow in ("ios-build", "android-build", "ios-patch", "android-patch"):
            self.assertIn("- $HOME/.shorebird", self._workflow_block(workflow))

    def test_shorebird_install_runs_before_ios_dependency_resolution(self) -> None:
        ios_build = self.contents.index("ios-build:")
        ios_patch = self.contents.index("ios-patch:")
        android_build = self.contents.index("android-build:")
        android_patch = self.contents.index("android-patch:")

        self.assertLess(
            self.contents.index("- *shorebird_install", ios_build),
            self.contents.index("- *prepare_ios_spm_packages", ios_build),
        )
        self.assertLess(
            self.contents.index("- *shorebird_install", ios_patch),
            self.contents.index("- *prepare_ios_spm_packages", ios_patch),
        )
        self.assertLess(
            self.contents.index("- *shorebird_install", android_build),
            self.contents.index("- *setup_local_properties", android_build),
        )
        self.assertLess(
            self.contents.index("- *shorebird_install", android_patch),
            self.contents.index("- *setup_local_properties", android_patch),
        )

    def _workflow_block(self, workflow_name: str) -> str:
        start = self.contents.index(f"  {workflow_name}:")
        next_workflow = re.search(r"^  [a-z0-9-]+:", self.contents[start + 1 :], re.MULTILINE)
        if next_workflow is None:
            return self.contents[start:]
        return self.contents[start : start + 1 + next_workflow.start()]

    def _shorebird_patch_commands(self) -> list[str]:
        commands = []
        lines = self.contents.splitlines()
        for index, line in enumerate(lines):
            if "shorebird patch " not in line:
                continue
            command_lines = [line]
            cursor = index
            while command_lines[-1].rstrip().endswith("\\"):
                cursor += 1
                command_lines.append(lines[cursor])
            commands.append("\n".join(command_lines))
        return commands


if __name__ == "__main__":
    unittest.main()
