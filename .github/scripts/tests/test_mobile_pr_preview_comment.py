import subprocess
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "mobile_pr_preview_comment.py"


class MobilePrPreviewCommentTest(unittest.TestCase):
    def run_renderer(self, *args: str) -> str:
        result = subprocess.run(
            ["python3", str(SCRIPT_PATH), *args],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(
            result.returncode,
            0,
            msg=f"renderer exited with {result.returncode}: {result.stderr}",
        )
        return result.stdout

    def test_renders_deployed_comment_with_refresh_line(self) -> None:
        output = self.run_renderer(
            "--mode",
            "deployed",
            "--sha",
            "212fe3360",
            "--updated-at",
            "2026-04-14 04:38:43 UTC",
            "--run-url",
            "https://github.com/divinevideo/divine-mobile/actions/runs/24381216336",
            "--preview-branch",
            "pr-3042",
            "--head-ref",
            "codex/feed-description-metadata",
            "--deployment-url",
            "https://b38b5fb6.openvine-app.pages.dev",
        )

        self.assertIn("Preview refreshed for `212fe33`", output)
        self.assertIn("https://b38b5fb6.openvine-app.pages.dev", output)
        self.assertIn(
            "https://github.com/divinevideo/divine-mobile/actions/runs/24381216336",
            output,
        )
        self.assertIn("`pr-3042`", output)
        self.assertIn("`codex/feed-description-metadata`", output)

    def test_renders_blocked_comment_with_refresh_line(self) -> None:
        output = self.run_renderer(
            "--mode",
            "blocked",
            "--sha",
            "212fe3360",
            "--updated-at",
            "2026-04-14 04:38:43 UTC",
            "--run-url",
            "https://github.com/divinevideo/divine-mobile/actions/runs/24381216336",
            "--preview-branch",
            "pr-3042",
            "--head-ref",
            "codex/feed-description-metadata",
        )

        self.assertIn("Preview refresh blocked for `212fe33`", output)
        self.assertIn("`CLOUDFLARE_API_TOKEN`", output)
        self.assertIn("`CLOUDFLARE_ACCOUNT_ID`", output)
        self.assertIn("`pr-3042`", output)
        self.assertIn("`codex/feed-description-metadata`", output)


if __name__ == "__main__":
    unittest.main()
