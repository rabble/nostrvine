import json
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
SHOREBIRD_DOC_PATH = (
    Path(__file__).resolve().parents[3] / "mobile" / "docs" / "SHOREBIRD_CODE_PUSH.md"
)
PROVENANCE_STORE_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "scripts"
    / "shorebird_provenance_store.sh"
)
CAPTION_GENERATOR_GRADLE_PATH = (
    Path(__file__).resolve().parents[3]
    / "mobile"
    / "packages"
    / "caption_generator"
    / "android"
    / "build.gradle.kts"
)


class CodemagicShorebirdConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contents = CODEMAGIC_PATH.read_text()
        self.mobile_ci_contents = MOBILE_CI_PATH.read_text()
        self.mise_contents = MISE_PATH.read_text()
        self.shorebird_doc_contents = SHOREBIRD_DOC_PATH.read_text()
        self.provenance_store_contents = PROVENANCE_STORE_PATH.read_text()
        self.caption_generator_gradle_contents = CAPTION_GENERATOR_GRADLE_PATH.read_text()

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

    def test_shorebird_required_defines_reject_empty_values(self) -> None:
        self.assertIn(
            "required_names.reject { |name| ENV.key?(name) && !ENV.fetch(name).empty? }",
            self.contents,
        )

    def test_shorebird_install_reuses_only_the_expected_cached_version(self) -> None:
        self.assertIn('EXPECTED_SHOREBIRD_VERSION="Shorebird 1.6.117"', self.contents)
        self.assertIn(
            'EXPECTED_SHOREBIRD_REVISION="45facdd4e4b3c39e0d260107977584f0b7c66bec"',
            self.contents,
        )
        self.assertIn('if [ -x "$SHOREBIRD_BIN" ]; then', self.contents)
        self.assertIn('git -C "$HOME/.shorebird" rev-parse HEAD', self.contents)
        self.assertRegex(
            self.contents,
            r"(?s)&shorebird_install.*?script: \|\n\s+set -euo pipefail\n",
        )

    def test_shorebird_cli_install_is_pinned_to_a_full_commit(self) -> None:
        self.assertRegex(
            self.contents,
            r'EXPECTED_SHOREBIRD_REVISION="[0-9a-f]{40}"',
        )
        self.assertIn('checkout --quiet --detach FETCH_HEAD', self.contents)
        self.assertNotIn("raw.githubusercontent.com/shorebirdtech/install", self.contents)
        self.assertNotRegex(self.contents, r"git clone .* (?:stable|v[0-9])")

    def test_shorebird_release_commands_are_signed_and_preflighted(self) -> None:
        self.assertIn("*preflight_shorebird_ios_release", self.contents)
        self.assertIn("*preflight_shorebird_android_release", self.contents)
        self.assertIn("shorebird releases list --platform=android --json", self.contents)
        self.assertIn("shorebird releases list --platform=ios --json", self.contents)
        self.assertEqual(2, self.contents.count("shorebird_release_preflight.rb"))
        self.assertNotIn("shorebird releases info", self.contents)
        self.assertIn("--build-name=$BUILD_NAME", self.contents)
        self.assertIn("--public-key-path=build/shorebird/patch_public_key.pem", self.contents)

    def test_ios_release_rejects_closed_app_store_version_before_shorebird(self) -> None:
        workflow = self._workflow_block("ios-build")
        self.assertIn(
            "app-store-connect get-latest-app-store-build-number",
            self.contents,
        )
        self.assertIn("--include-version --json", self.contents)
        self.assertEqual(1, self.contents.count("ios_store_version_preflight.rb"))
        self.assertLess(
            workflow.index("- *preflight_shorebird_ios_release"),
            workflow.index("- *build_ios"),
        )

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
            workflow_contents = workflow.read_text()
            uses_flutter = re.search(
                r"flutter_package\.yml|subosito/flutter-action|"
                r"\bflutter\s+(?:analyze|build|drive|pub|test)\b",
                workflow_contents,
            )
            if uses_flutter is None:
                continue
            versions = re.findall(
                r"flutter(?:-|_)version:\s*[\"']?([^\"'\s]+)",
                workflow_contents,
            )
            if set(versions) != {expected}:
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

    def test_shorebird_patch_workflows_use_private_provenance(self) -> None:
        self.assertIn('if [ "$CM_BRANCH" != "main" ]; then', self.contents)
        self.assertIn("RELEASE_COMMIT:", self.contents)
        self.assertIn("*fetch_and_verify_shorebird_provenance", self.contents)
        self.assertIn("shorebird_provenance_store.sh fetch", self.contents)
        self.assertIn("shorebird_provenance.rb verify", self.contents)
        self.assertIn("git diff --name-only", self.contents)
        self.assertIn("*prepare_patch_source", self.contents)

    def test_shorebird_workflows_define_every_variable_their_scripts_read(self) -> None:
        resolved = json.loads(
            subprocess.run(
                [
                    "ruby",
                    "-ryaml",
                    "-rjson",
                    "-e",
                    "print JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
                    str(CODEMAGIC_PATH),
                ],
                check=True,
                text=True,
                capture_output=True,
            ).stdout
        )

        for name in ("ios-build", "android-build", "ios-patch", "android-patch"):
            workflow = resolved["workflows"][name]
            declared = set(workflow["environment"].get("vars") or {})
            scripts = "\n".join(
                step.get("script", "") for step in workflow["scripts"] if isinstance(step, dict)
            )
            # Every provenance step runs under `set -u`, so a workflow-local
            # variable its scripts read but never declare aborts the build.
            for variable in ("FLUTTER_VERSION", "SHOREBIRD_PLATFORM"):
                if re.search(rf"\${{?{variable}}}?\b", scripts):
                    self.assertIn(variable, declared, f"{name} reads ${variable} without declaring it")

    def test_store_release_workflows_require_main_and_emit_provenance(self) -> None:
        for workflow_name in ("ios-build", "android-build"):
            workflow = self._workflow_block(workflow_name)
            self.assertIn("- *verify_shorebird_release_source", workflow)
            self.assertIn("- *emit_shorebird_provenance", workflow)
        self.assertIn("shorebird_provenance_store.sh create", self.contents)
        self.assertIn("refusing to overwrite it", self.provenance_store_contents.lower())

    def test_existing_ios_release_has_verified_main_tree_equivalence(self) -> None:
        baseline_commit = "2504f4d871a9c1790e3e39f8398027bdc5105d04"
        expected_tree = "a17e0660a782e439c5d405c2d06dd49e5b7fbc81"
        repo_root = CODEMAGIC_PATH.parent

        result = subprocess.run(
            ["git", "rev-parse", f"{baseline_commit}^{{tree}}"],
            cwd=repo_root,
            check=True,
            text=True,
            capture_output=True,
        )
        self.assertEqual(expected_tree, result.stdout.strip())

    def test_ci_config_job_fetches_history_for_release_tree_verification(self) -> None:
        job_start = self.mobile_ci_contents.index("  ci-config-tests:")
        next_job = self.mobile_ci_contents.index("\n  generated-files:", job_start)
        job = self.mobile_ci_contents[job_start:next_job]

        self.assertIn("fetch-depth: 0", job)

    def test_caption_generator_names_missing_flutter_embedding_jar(self) -> None:
        self.assertIn("if (!flutterDebugEmbeddingJar.isFile)", self.caption_generator_gradle_contents)
        self.assertIn("Flutter debug embedding JAR not found at", self.caption_generator_gradle_contents)
        self.assertIn("flutterDebugEmbeddingJar.absolutePath", self.caption_generator_gradle_contents)

    def test_shorebird_patch_workflows_block_native_asset_and_dependency_changes(self) -> None:
        self.assertIn("BLOCKED_PATCH_PATHS=$(git diff --name-only", self.contents)
        self.assertIn("'android/**'", self.contents)
        self.assertIn("'ios/**'", self.contents)
        self.assertIn("'assets/**'", self.contents)
        self.assertIn("'shaders/**'", self.contents)
        self.assertIn("'pubspec.yaml'", self.contents)
        self.assertIn("'pubspec.lock'", self.contents)
        self.assertIn("'packages/**/android/**'", self.contents)
        self.assertIn("'packages/**/assets/**'", self.contents)
        self.assertIn("'packages/**/shaders/**'", self.contents)
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
        for workflow_name in ("ios-build", "ios-patch"):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(
                workflow.index("- *shorebird_install"),
                workflow.index("- *prepare_ios_spm_packages"),
            )
        for workflow_name in ("android-build", "android-patch"):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(
                workflow.index("- *shorebird_install"),
                workflow.index("- *setup_local_properties"),
            )

    def test_shorebird_release_preflight_runs_before_store_build(self) -> None:
        for workflow_name, preflight, build in (
            ("ios-build", "- *preflight_shorebird_ios_release", "- *build_ios"),
            ("android-build", "- *preflight_shorebird_android_release", "- *build_aab"),
        ):
            workflow = self._workflow_block(workflow_name)
            self.assertLess(workflow.index(preflight), workflow.index(build))

    def test_shorebird_release_builds_fail_on_missing_preflight_output(self) -> None:
        for anchor in ("build_aab", "build_ios"):
            self.assertRegex(
                self.contents,
                rf"(?s)&{anchor}.*?script: \|\n\s+set -euo pipefail\n",
            )

    def test_runbook_uses_current_patch_promotion_and_reporting(self) -> None:
        set_track = (
            "shorebird patches set-track --release <version> --patch <n> "
            "--track stable"
        )
        self.assertIn(set_track, self.shorebird_doc_contents)
        self.assertLess(
            self.shorebird_doc_contents.index(set_track),
            self.shorebird_doc_contents.index("shorebird patches promote"),
        )
        self.assertIn("`shorebird_code_push` is a runtime dependency", self.shorebird_doc_contents)
        self.assertIn("Crashlytics", self.shorebird_doc_contents)

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
