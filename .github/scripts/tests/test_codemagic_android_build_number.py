import unittest
from pathlib import Path


CODEMAGIC_PATH = Path(__file__).resolve().parents[3] / "codemagic.yaml"


class CodemagicAndroidBuildNumberTest(unittest.TestCase):
    def test_android_aab_build_uses_google_play_floor(self) -> None:
        contents = CODEMAGIC_PATH.read_text()

        self.assertIn(
            'google-play get-latest-build-number --package-name "co.openvine.app"',
            contents,
        )
        self.assertIn("BUILD_NUMBER=$PROJECT_BUILD_NUMBER", contents)
        self.assertIn(
            'NEXT_PLAY_BUILD_NUMBER=$((LATEST_GOOGLE_PLAY_BUILD_NUMBER + 1))',
            contents,
        )
        self.assertIn(
            'if [ "$NEXT_PLAY_BUILD_NUMBER" -gt "$BUILD_NUMBER" ]; then',
            contents,
        )
        self.assertNotIn("PROJECT_BUILD_NUMBER + 8", contents)


if __name__ == "__main__":
    unittest.main()
