import unittest
from pathlib import Path


CODEMAGIC_PATH = Path(__file__).resolve().parents[3] / "codemagic.yaml"


class CodemagicAndroidBuildNumberTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contents = CODEMAGIC_PATH.read_text()

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
        self.assertIn("--build-name=$BUILD_NAME", self.contents)
        self.assertIn("--public-key-path=build/shorebird/patch_public_key.pem", self.contents)
        self.assertIn("already exists and is active", self.contents)

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

    def test_shorebird_cache_is_enabled_for_release_and_patch_workflows(self) -> None:
        self.assertEqual(self.contents.count("- $HOME/.shorebird"), 4)

    def test_shorebird_install_runs_before_ios_dependency_resolution(self) -> None:
        ios_build = self.contents.index("ios-build:")
        ios_patch = self.contents.index("ios-patch:")
        android_build = self.contents.index("android-build:")
        android_patch = self.contents.index("android-patch:")
        macos_build = self.contents.index("macos-build:")

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
        self.assertLess(android_patch, macos_build)


if __name__ == "__main__":
    unittest.main()
