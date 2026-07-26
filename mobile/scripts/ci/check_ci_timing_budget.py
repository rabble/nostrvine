#!/usr/bin/env python3
"""Fail or warn when a Mobile CI job exceeds its wall-clock budget.

Reads `.github/ci-timing-budgets.json` and the job list for one workflow run,
and compares each budgeted job's duration against its `warn` / `fail`
thresholds. Intended to run from the `mobile-ci` gate job, which only starts
once every other job in the run has finished.

Job durations come from `gh api` by default; `--jobs-json` accepts the same
payload from a file so the logic is testable without the network.

Exit codes:
  0  every budgeted job inside its fail threshold (warnings may be emitted)
  1  at least one budgeted job over its fail threshold
  2  the check could not run (bad budget file, no job data)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from ci_github import GhApiError, duration_seconds as elapsed_seconds
from ci_github import gh_json_pages, parse_timestamp


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--budgets", required=True, help="Path to ci-timing-budgets.json")
    parser.add_argument("--repo", help="owner/name, for the gh api call")
    parser.add_argument("--run-id", help="Workflow run id to inspect")
    parser.add_argument(
        "--jobs-json",
        help="Read the jobs payload from this file instead of calling gh api",
    )
    return parser.parse_args()


def load_budgets(path: Path) -> dict[str, dict[str, float]]:
    try:
        raw = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail_to_run(f"could not read budgets at {path}: {error}")
    if not isinstance(raw, dict):
        fail_to_run(f"{path} must contain a JSON object")
    budgets = raw.get("jobs")
    if not isinstance(budgets, dict) or not budgets:
        fail_to_run(f"{path} has no non-empty 'jobs' object")
    parsed: dict[str, dict[str, float]] = {}
    for name, entry in budgets.items():
        if not isinstance(name, str):
            fail_to_run("budget names must be strings")
        if not isinstance(entry, dict) or "warn" not in entry or "fail" not in entry:
            fail_to_run(f"budget for {name!r} needs both 'warn' and 'fail'")
        warn, fail = entry["warn"], entry["fail"]
        if not is_number(warn) or not is_number(fail):
            fail_to_run(f"budget for {name!r} needs numeric 'warn' and 'fail'")
        if warn > fail:
            fail_to_run(f"budget for {name!r} has warn ({warn}) above fail ({fail})")
        parsed[name] = {"warn": float(warn), "fail": float(fail)}
    return parsed


def load_jobs(args: argparse.Namespace) -> list[dict]:
    if args.jobs_json:
        try:
            payload = json.loads(Path(args.jobs_json).read_text())
        except (OSError, json.JSONDecodeError) as error:
            fail_to_run(f"could not read jobs payload: {error}")
        if not isinstance(payload, dict):
            fail_to_run("job payload must contain a JSON object")
        jobs = payload.get("jobs")
    else:
        if not args.repo or not args.run_id:
            fail_to_run("--repo and --run-id are required without --jobs-json")
        try:
            pages = gh_json_pages(
                f"/repos/{args.repo}/actions/runs/{args.run_id}/jobs?per_page=100",
            )
        except GhApiError as error:
            fail_to_run(f"gh api failed: {error}")
        jobs = []
        for page in pages:
            page_jobs = page.get("jobs")
            if not isinstance(page_jobs, list):
                fail_to_run("job payload contained a page with no jobs list")
            jobs.extend(page_jobs)
    if not isinstance(jobs, list) or not jobs:
        fail_to_run("job payload contained no jobs")
    for job in jobs:
        if not isinstance(job, dict):
            fail_to_run("job payload contained a non-object job")
    return jobs


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def fail_to_run(message: str) -> None:
    """Exit 2. The check failing open would make the guard decorative."""
    print(f"::error title=CI timing budget::cannot run — {message}")
    sys.exit(2)


def duration_seconds(job: dict) -> float | None:
    started, completed = job.get("started_at"), job.get("completed_at")
    if not started or not completed:
        return None
    if not isinstance(started, str) or not isinstance(completed, str):
        fail_to_run(f"job {job.get('name', '<unknown>')!r} has non-string timestamps")
    try:
        parse_timestamp(started)
        parse_timestamp(completed)
    except ValueError as error:
        fail_to_run(f"job {job.get('name', '<unknown>')!r} has an invalid timestamp: {error}")
    return elapsed_seconds(started, completed)


def matches(job_name: str, budget_name: str) -> bool:
    """Exact name, or the sharded/parameterised form of it.

    A matrix leg renders as 'Tests (shard 0/4)', so one budget key covers the
    whole matrix. Requiring the ' (' guards against 'Tests' also swallowing a
    hypothetical 'Tests Extra'.
    """
    return job_name == budget_name or job_name.startswith(f"{budget_name} (")


def main() -> int:
    args = parse_args()
    budgets = load_budgets(Path(args.budgets))
    jobs = load_jobs(args)

    over_fail: list[str] = []
    unseen = []
    print(f"{'job':<40}{'seconds':>9}{'warn':>7}{'fail':>7}  verdict")

    for budget_name, thresholds in sorted(budgets.items()):
        matched = [
            job
            for job in jobs
            if matches(job.get("name", ""), budget_name) and job.get("conclusion") == "success"
        ]
        if not matched:
            unseen.append(budget_name)
            continue
        for job in matched:
            seconds = duration_seconds(job)
            if seconds is None:
                fail_to_run(f"job {job.get('name', '<unknown>')!r} has no completed duration")
            name = job["name"]
            if seconds > thresholds["fail"]:
                verdict = "OVER FAIL"
                over_fail.append(f"{name} took {seconds:.0f}s (fail budget {thresholds['fail']:.0f}s)")
            elif seconds > thresholds["warn"]:
                verdict = "over warn"
                print(
                    f"::warning title=CI timing budget::{name} took {seconds:.0f}s, "
                    f"over its {thresholds['warn']:.0f}s warn budget "
                    f"(fails at {thresholds['fail']:.0f}s). See .github/ci-timing-budgets.json."
                )
            else:
                verdict = "ok"
            print(
                f"{name:<40}{seconds:>9.0f}{thresholds['warn']:>7.0f}"
                f"{thresholds['fail']:>7.0f}  {verdict}"
            )

    if unseen:
        # Reported, never silently treated as passing: a renamed or skipped job
        # would otherwise drop out of the budget with nobody noticing.
        print(
            "::notice title=CI timing budget::no successful run of these budgeted jobs "
            f"in this workflow run (skipped or renamed): {', '.join(sorted(unseen))}"
        )

    if over_fail:
        for line in over_fail:
            print(f"::error title=CI timing budget::{line}")
        print(
            "\nA job blew its wall-clock budget. Either something got slower, or the "
            "budget is genuinely stale — measure, then fix the regression or raise "
            "the budget in .github/ci-timing-budgets.json with the number in the PR body."
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
