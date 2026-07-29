#!/usr/bin/env python3
"""Shared GitHub Actions timing helpers for Mobile CI scripts."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime
from typing import Any


class GhApiError(RuntimeError):
    """Raised when `gh api` cannot return a JSON payload."""


def gh_json(*args: str) -> dict[str, Any]:
    command = ["gh", "api", *args]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise GhApiError(detail or f"gh api exited {result.returncode}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise GhApiError(f"gh api returned malformed JSON: {error}") from error
    if not isinstance(payload, dict):
        raise GhApiError("gh api returned a non-object JSON payload")
    return payload


def gh_json_pages(*args: str) -> list[dict[str, Any]]:
    command = ["gh", "api", "--paginate", "--slurp", *args]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise GhApiError(detail or f"gh api exited {result.returncode}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise GhApiError(f"gh api returned malformed paginated JSON: {error}") from error
    if not isinstance(payload, list):
        raise GhApiError("gh api returned a non-list paginated JSON payload")
    for page in payload:
        if not isinstance(page, dict):
            raise GhApiError("gh api returned a non-object page")
    return payload


def parse_timestamp(value: str | None) -> datetime | None:
    if value is None:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def duration_seconds(started_at: str | None, completed_at: str | None) -> float:
    start = parse_timestamp(started_at)
    end = parse_timestamp(completed_at)
    if start is None or end is None:
        return 0.0
    return (end - start).total_seconds()
