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
import subprocess
import sys
from pathlib import Path


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
    budgets = raw.get("jobs")
    if not isinstance(budgets, dict) or not budgets:
        fail_to_run(f"{path} has no non-empty 'jobs' object")
    for name, entry in budgets.items():
        if not isinstance(entry, dict) or "warn" not in entry or "fail" not in entry:
            fail_to_run(f"budget for {name!r} needs both 'warn' and 'fail'")
        if entry["warn"] > entry["fail"]:
            fail_to_run(f"budget for {name!r} has warn ({entry['warn']}) above fail ({entry['fail']})")
    return budgets


def load_jobs(args: argparse.Namespace) -> list[dict]:
    if args.jobs_json:
        try:
            payload = json.loads(Path(args.jobs_json).read_text())
        except (OSError, json.JSONDecodeError) as error:
            fail_to_run(f"could not read jobs payload: {error}")
    else:
        if not args.repo or not args.run_id:
            fail_to_run("--repo and --run-id are required without --jobs-json")
        command = [
            "gh",
            "api",
            "--paginate",
            f"/repos/{args.repo}/actions/runs/{args.run_id}/jobs?per_page=100",
        ]
        try:
            completed = subprocess.run(command, capture_output=True, text=True, check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            fail_to_run(f"gh api failed: {error}")
        payload = json.loads(completed.stdout)
    jobs = payload.get("jobs")
    if not isinstance(jobs, list) or not jobs:
        fail_to_run("job payload contained no jobs")
    return jobs


def fail_to_run(message: str) -> None:
    """Exit 2. The check failing open would make the guard decorative."""
    print(f"::error title=CI timing budget::cannot run — {message}")
    sys.exit(2)


def duration_seconds(job: dict) -> float | None:
    from datetime import datetime

    started, completed = job.get("started_at"), job.get("completed_at")
    if not started or not completed:
        return None
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    return (datetime.strptime(completed, fmt) - datetime.strptime(started, fmt)).total_seconds()


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
                continue
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
