#!/usr/bin/env python3
"""Render PR preview comments for the mobile preview deploy workflow."""

from __future__ import annotations

import argparse
import sys
from textwrap import dedent


def short_sha(sha: str) -> str:
    return sha[:7]


def render_deployed_comment(args: argparse.Namespace) -> str:
    sha = short_sha(args.sha)
    return dedent(
        f"""\
        ## Mobile PR Preview

        Preview refreshed for `{sha}`

        Last refresh: `{sha}` at {args.updated_at} ([preview run]({args.run_url}))

        | Property | Value |
        | --- | --- |
        | Preview URL | {args.deployment_url} |
        | Pages project | `openvine-app` |
        | Preview branch | `{args.preview_branch}` |
        | PR branch | `{args.head_ref}` |
        | Commit | `{sha}` |
        """
    )


def render_blocked_comment(args: argparse.Namespace) -> str:
    sha = short_sha(args.sha)
    return dedent(
        f"""\
        ## Mobile PR Preview

        Preview refresh blocked for `{sha}`

        Last refresh: `{sha}` at {args.updated_at} ([preview run]({args.run_url}))

        Preview deployment is not configured for this repository yet.

        Missing GitHub Actions secrets:
        - `CLOUDFLARE_API_TOKEN`
        - `CLOUDFLARE_ACCOUNT_ID`

        Once those are added, this workflow will deploy this PR to the existing `openvine-app` Pages project on branch `{args.preview_branch}`.

        | Property | Value |
        | --- | --- |
        | Preview branch | `{args.preview_branch}` |
        | PR branch | `{args.head_ref}` |
        | Commit | `{sha}` |
        """
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("deployed", "blocked"), required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--updated-at", required=True)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--preview-branch", required=True)
    parser.add_argument("--head-ref", required=True)
    parser.add_argument("--deployment-url")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.mode == "deployed":
        if not args.deployment_url:
            raise SystemExit("--deployment-url is required for deployed mode")
        comment = render_deployed_comment(args)
    else:
        comment = render_blocked_comment(args)

    sys.stdout.write(comment)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
