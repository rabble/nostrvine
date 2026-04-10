#!/usr/bin/env python3
"""Summarize Mobile CI timing data from GitHub Actions via `gh api`.

Examples:
  python3 mobile/scripts/ci/report_mobile_ci_run.py --pr 2919
  python3 mobile/scripts/ci/report_mobile_ci_run.py --run-id 24161889450
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Any


DEFAULT_REPO = "divinevideo/divine-mobile"
DEFAULT_WORKFLOW_ID = "214414349"


@dataclass
class StepTiming:
  name: str
  started_at: str | None
  completed_at: str | None

  @property
  def duration_seconds(self) -> float:
    return duration_seconds(self.started_at, self.completed_at)


@dataclass
class JobTiming:
  name: str
  status: str
  conclusion: str | None
  started_at: str | None
  completed_at: str | None
  html_url: str
  steps: list[StepTiming]

  @property
  def duration_seconds(self) -> float:
    return duration_seconds(self.started_at, self.completed_at)

  @property
  def setup_seconds(self) -> float:
    setup_names = {
      "Set up job",
      "Checkout repository",
      "🐦 Setup Flutter",
      "📦 Install dependencies",
      "Post 🐦 Setup Flutter",
      "Post Checkout repository",
      "Complete job",
    }
    return sum(step.duration_seconds for step in self.steps if step.name in setup_names)


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser()
  parser.add_argument("--repo", default=DEFAULT_REPO)
  parser.add_argument("--workflow-id", default=DEFAULT_WORKFLOW_ID)
  parser.add_argument("--pr", type=int)
  parser.add_argument("--run-id", type=int)
  parser.add_argument("--event", choices=["push", "pull_request"])
  return parser.parse_args()


def gh_json(*args: str) -> dict[str, Any]:
  command = ["gh", "api", *args]
  result = subprocess.run(command, capture_output=True, text=True, check=False)
  if result.returncode != 0:
    print(result.stderr.strip(), file=sys.stderr)
    raise SystemExit(result.returncode)
  return json.loads(result.stdout)


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


def format_seconds(seconds: float) -> str:
  total = int(round(seconds))
  minutes, secs = divmod(total, 60)
  hours, minutes = divmod(minutes, 60)
  if hours:
    return f"{hours}h {minutes}m {secs}s"
  return f"{minutes}m {secs}s"


def get_branch_for_pr(repo: str, pr_number: int) -> str:
  payload = gh_json(f"repos/{repo}/pulls/{pr_number}")
  return payload["head"]["ref"]


def get_run(repo: str, workflow_id: str, run_id: int | None, branch: str | None, event: str | None) -> dict[str, Any]:
  if run_id is not None:
    return gh_json(f"repos/{repo}/actions/runs/{run_id}")

  endpoint = f"repos/{repo}/actions/workflows/{workflow_id}/runs?per_page=20"
  if branch:
    endpoint += f"&branch={branch}"
  if event:
    endpoint += f"&event={event}"

  payload = gh_json(endpoint)
  runs = payload.get("workflow_runs", [])
  if not runs:
    print("No workflow runs found for the given query.", file=sys.stderr)
    raise SystemExit(1)
  return runs[0]


def get_jobs(repo: str, run_id: int) -> list[JobTiming]:
  payload = gh_json(f"repos/{repo}/actions/runs/{run_id}/jobs?per_page=100")
  jobs: list[JobTiming] = []
  for job in payload.get("jobs", []):
    steps = [
      StepTiming(
        name=step["name"],
        started_at=step.get("started_at"),
        completed_at=step.get("completed_at"),
      )
      for step in job.get("steps", [])
    ]
    jobs.append(
      JobTiming(
        name=job["name"],
        status=job["status"],
        conclusion=job.get("conclusion"),
        started_at=job.get("started_at"),
        completed_at=job.get("completed_at"),
        html_url=job["html_url"],
        steps=steps,
      )
    )
  return jobs


def main() -> int:
  args = parse_args()
  if args.pr is None and args.run_id is None:
    print("Pass either --pr or --run-id.", file=sys.stderr)
    return 2

  branch = get_branch_for_pr(args.repo, args.pr) if args.pr is not None else None
  run = get_run(args.repo, args.workflow_id, args.run_id, branch, args.event)
  jobs = get_jobs(args.repo, run["id"])

  print(f"Workflow: {run['name']}")
  print(f"Run ID: {run['id']}")
  print(f"URL: {run['html_url']}")
  print(f"Event: {run['event']}")
  print(f"Branch: {run['head_branch']}")
  print(f"Status: {run['status']}")
  print(f"Conclusion: {run.get('conclusion')}")
  print(f"Workflow wall time: {format_seconds(duration_seconds(run.get('run_started_at'), run.get('updated_at')))}")

  if not jobs:
    print("Jobs: none")
    print("This usually means GitHub rejected the workflow before any job was created.")
    return 0

  print()
  print("Jobs:")
  for job in jobs:
    print(
      f"- {job.name}: total={format_seconds(job.duration_seconds)}, "
      f"setup={format_seconds(job.setup_seconds)}, "
      f"status={job.status}, conclusion={job.conclusion}"
    )

  test_jobs = [job for job in jobs if job.name.startswith("Tests")]
  if test_jobs:
    longest = max(test_jobs, key=lambda job: job.duration_seconds)
    shortest = min(test_jobs, key=lambda job: job.duration_seconds)
    print()
    print("Test shard summary:")
    print(f"- longest shard: {longest.name} at {format_seconds(longest.duration_seconds)}")
    print(f"- shortest shard: {shortest.name} at {format_seconds(shortest.duration_seconds)}")
    print(
      f"- spread: {format_seconds(longest.duration_seconds - shortest.duration_seconds)}"
    )

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
