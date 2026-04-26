#!/usr/bin/env python3
# ABOUTME: Library + CLI for the iOS QA PR build allocator and notifier.
# ABOUTME: Pure Python with stdlib only — runs in GitHub Actions and Codemagic.

"""ios_qa_slots: trust, allocation, comments, directory, and CLI."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable, Optional, Sequence


STATE_MARKER_PREFIX = "<!-- divine-ios-qa-build:v1 "
STATE_MARKER_SUFFIX = " -->"
DIRECTORY_MARKER_PREFIX = "<!-- divine-ios-qa-directory:v1 "
NEEDS_QA_LABEL = "needs-ios-qa"
LABEL_BUILDING = "ios-qa:building"
LABEL_READY = "ios-qa:ready"
LABEL_QUEUED = "ios-qa:queued"
LABEL_FAILED = "ios-qa:failed"
STATE_LABELS = (LABEL_BUILDING, LABEL_READY, LABEL_QUEUED, LABEL_FAILED)
TRUSTED_OWNER = "divinevideo"

_SLOT_LABEL_RE = re.compile(r"^ios-qa-slot-(\d{2})$")
_RELEVANT_PATH_PREFIXES = ("mobile/",)
_RELEVANT_EXACT_PATHS = ("codemagic.yaml",)


def load_slots(path: Path | str) -> list[dict]:
    return json.loads(Path(path).read_text(encoding="utf-8"))["slots"]


def enabled_slots(slots: Sequence[dict]) -> list[dict]:
    return [
        s
        for s in slots
        if s.get("enabled") is True and s.get("firebaseAppId")
    ]


def required_labels(slots: Sequence[dict]) -> list[str]:
    labels: list[str] = [slot["label"] for slot in slots]
    labels.extend(STATE_LABELS)
    labels.append(NEEDS_QA_LABEL)
    return labels


def is_trusted_pr(head_repo_owner: str, *, author_is_org_member: bool) -> bool:
    if head_repo_owner == TRUSTED_OWNER:
        return True
    return bool(author_is_org_member)


def is_eligible_pr(*, is_draft: bool, labels: Sequence[str]) -> bool:
    if not is_draft:
        return True
    return NEEDS_QA_LABEL in labels


def current_slot(labels: Iterable[str]) -> Optional[str]:
    for label in labels:
        match = _SLOT_LABEL_RE.match(label)
        if match:
            return f"qa{match.group(1)}"
    return None


def slot_labels_to_remove(
    labels: Iterable[str],
    *,
    keep_label: Optional[str] = None,
) -> list[str]:
    return [
        label
        for label in labels
        if _SLOT_LABEL_RE.match(label) and label != keep_label
    ]


def relevant_changes(changed_files: Iterable[str]) -> bool:
    for path in changed_files:
        if path in _RELEVANT_EXACT_PATHS:
            return True
        if any(path.startswith(prefix) for prefix in _RELEVANT_PATH_PREFIXES):
            return True
    return False


def _has_qa_label(labels: Sequence[str]) -> bool:
    return any(
        _SLOT_LABEL_RE.match(label) or label in STATE_LABELS or label == NEEDS_QA_LABEL
        for label in labels
    )


def decide_action(
    *,
    is_closed: bool,
    has_relevant_changes: bool,
    labels: Sequence[str],
) -> str:
    """Return 'allocate', 'cleanup', or 'skip'."""
    if is_closed:
        return "cleanup"
    if not has_relevant_changes:
        return "cleanup" if _has_qa_label(labels) else "skip"
    return "allocate"


def choose_slot(
    slots: Sequence[dict],
    prs: Sequence[dict],
) -> dict[int, str]:
    """Assign each PR a slot id (e.g. 'qa01') or the literal 'queued'.

    Sort PRs by ``eligibility_at`` then ``number`` so order is deterministic.
    Existing slot labels are preserved when the slot is still enabled.
    """
    enabled = enabled_slots(slots)
    enabled_ids = {s["slot"] for s in enabled}
    sorted_prs = sorted(prs, key=lambda p: (p["eligibility_at"], p["number"]))

    occupied: dict[str, int] = {}
    assignments: dict[int, str] = {}

    # First pass: preserve still-valid slot assignments.
    for pr in sorted_prs:
        existing = current_slot(pr.get("labels", []))
        if existing and existing in enabled_ids and existing not in occupied:
            occupied[existing] = pr["number"]
            assignments[pr["number"]] = existing

    # Second pass: assign free slots in PR order.
    for pr in sorted_prs:
        if pr["number"] in assignments:
            continue
        free = next(
            (s for s in enabled if s["slot"] not in occupied),
            None,
        )
        if free is None:
            assignments[pr["number"]] = "queued"
        else:
            occupied[free["slot"]] = pr["number"]
            assignments[pr["number"]] = free["slot"]

    return assignments


def render_state_marker(state: dict[str, Any]) -> str:
    return STATE_MARKER_PREFIX + json.dumps(state, sort_keys=True) + STATE_MARKER_SUFFIX


def parse_state_marker(comment_body: Optional[str]) -> Optional[dict]:
    if not comment_body:
        return None
    start = comment_body.find(STATE_MARKER_PREFIX)
    if start < 0:
        return None
    end = comment_body.find(STATE_MARKER_SUFFIX, start + len(STATE_MARKER_PREFIX))
    if end < 0:
        return None
    payload = comment_body[start + len(STATE_MARKER_PREFIX):end]
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return None


def extract_firebase_testing_uri(
    distribution_json: dict[str, Any],
) -> Optional[str]:
    """Pull testing_uri from known Firebase CLI JSON shapes.

    Recognized shapes:
      - {"testing_uri": "..."}
      - {"result": {"testing_uri": "..."}}
      - {"result": {"release": {"testing_uri": "..."}}}

    Returns None when only ``binary_download_uri`` is present — that link
    expires within an hour and is not acceptable for QA comments.
    """
    candidates: list[Any] = [distribution_json]
    if isinstance(distribution_json, dict):
        result = distribution_json.get("result")
        if isinstance(result, dict):
            candidates.append(result)
            release = result.get("release")
            if isinstance(release, dict):
                candidates.append(release)
    for c in candidates:
        if isinstance(c, dict):
            uri = c.get("testing_uri")
            if isinstance(uri, str) and uri:
                return uri
    return None


def _status_heading(status: str, pr_number: int) -> str:
    table = {
        "ready": ("Ready", f"iOS QA build ready for PR #{pr_number}"),
        "building": ("Building", f"Building iOS QA for PR #{pr_number}"),
        "queued": ("Queued", f"iOS QA build queued for PR #{pr_number}"),
        "failed": ("Failed", f"iOS QA build failed for PR #{pr_number}"),
        "stale": ("Stale", f"iOS QA build skipped (stale) for PR #{pr_number}"),
    }
    label, title = table.get(status, (status.title(), f"iOS QA build {status} for PR #{pr_number}"))
    return f"## {label} — {title}"


def render_status_comment(
    *,
    status: str,
    pr_number: int,
    slot: Optional[str],
    sha: str,
    codemagic_build_url: Optional[str] = None,
    codemagic_build_id: Optional[str] = None,
    firebase_testing_uri: Optional[str] = None,
    failure_reason: Optional[str] = None,
    updated_at: Optional[str] = None,
) -> str:
    """Render the sticky PR comment body, including a hidden state marker."""
    lines: list[str] = [_status_heading(status, pr_number), ""]
    lines.append("| Field | Value |")
    lines.append("|---|---|")
    lines.append(f"| Slot | `{slot or 'unassigned'}` |")
    lines.append(f"| Commit | `{sha}` |")
    if firebase_testing_uri:
        lines.append(f"| Install | [{firebase_testing_uri}]({firebase_testing_uri}) |")
    if codemagic_build_url:
        lines.append(f"| Codemagic | [{codemagic_build_url}]({codemagic_build_url}) |")
    if failure_reason:
        lines.append(f"| Reason | {failure_reason} |")
    if updated_at:
        lines.append(f"| Updated | {updated_at} |")
    lines.append("")
    state = {
        "slot": slot,
        "pr_number": pr_number,
        "sha": sha,
        "status": status,
        "codemagic_build_id": codemagic_build_id,
        "codemagic_build_url": codemagic_build_url,
        "firebase_testing_uri": firebase_testing_uri,
        "failure_reason": failure_reason,
        "updated_at": updated_at,
    }
    lines.append(render_state_marker(state))
    return "\n".join(lines) + "\n"


def render_directory(
    rows: Sequence[dict],
    *,
    updated_at: str,
) -> str:
    """Render the active QA build directory body for a tracking issue."""
    lines: list[str] = [
        "# iOS QA PR Builds",
        "",
        f"_Updated {updated_at}_",
        "",
        "| Slot | Status | PR | Commit | Install | Codemagic |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        slot = row.get("slot") or "—"
        status = row.get("status", "unknown")
        pr_number = row.get("pr_number")
        sha = row.get("sha", "")
        firebase = row.get("firebase_testing_uri")
        codemagic = row.get("codemagic_build_url")
        install = f"[install]({firebase})" if firebase else "—"
        cm = f"[build]({codemagic})" if codemagic else "—"
        lines.append(
            f"| `{slot}` | {status} | PR #{pr_number} | `{sha}` | {install} | {cm} |",
        )
    lines.append("")
    lines.append(
        DIRECTORY_MARKER_PREFIX
        + json.dumps({"updated_at": updated_at}, sort_keys=True)
        + STATE_MARKER_SUFFIX,
    )
    return "\n".join(lines) + "\n"


def directory_rows_from_reconcile(
    reconcile: dict[Any, dict],
    prs: dict[int, dict],
) -> list[dict]:
    rows: list[dict] = []
    for number_key, decision in reconcile.items():
        if decision.get("action") != "allocate":
            continue
        number = int(number_key)
        pr = prs.get(number) or {}
        slot = decision.get("slot") or {}
        slot_id = slot.get("slot")
        head_sha = pr.get("head_sha", "")
        row = {
            "slot": slot_id,
            "status": decision.get("status"),
            "pr_number": number,
            "sha": head_sha,
            "firebase_testing_uri": None,
            "codemagic_build_url": None,
        }

        state = pr.get("qa_comment_state") or {}
        if isinstance(state, dict):
            state_sha = state.get("sha")
            state_slot = state.get("slot")
            if state_sha == head_sha and (slot_id is None or state_slot == slot_id):
                row["status"] = state.get("status") or row["status"]
                row["firebase_testing_uri"] = state.get("firebase_testing_uri")
                row["codemagic_build_url"] = state.get("codemagic_build_url")
        rows.append(row)
    return rows


def render_codemagic_payload(
    *,
    app_id: str,
    workflow_id: str,
    branch: str,
    pr: dict,
    slot: dict,
    default_env: str,
) -> dict:
    return {
        "appId": app_id,
        "workflowId": workflow_id,
        "branch": branch,
        "labels": [
            f"pr-{pr['number']}",
            slot["slot"],
        ],
        "environment": {
            "variables": {
                "PR_NUMBER": str(pr["number"]),
                "PR_HEAD_SHA": pr["head_sha"],
                "PR_HEAD_REPO": pr["head_repo"],
                "PR_HEAD_REF": pr["head_ref"],
                "QA_SLOT": slot["slot"],
                "QA_BUNDLE_ID": slot["bundleId"],
                "QA_EXTENSION_BUNDLE_ID": slot["extensionBundleId"],
                "QA_APP_GROUP": slot["appGroup"],
                "QA_DISPLAY_NAME": slot["displayName"],
                "QA_FIREBASE_APP_ID": slot["firebaseAppId"],
                "DEFAULT_ENV": default_env,
                "CODEMAGIC_APP_ID": app_id,
            },
        },
    }


def cleanup_for_closed_pr(
    *,
    pr_number: int,
    labels: Sequence[str],
) -> dict:
    to_remove = [
        label
        for label in labels
        if _SLOT_LABEL_RE.match(label)
        or label in STATE_LABELS
        or label == NEEDS_QA_LABEL
    ]
    return {
        "labels_to_remove": to_remove,
        "mirror_branch": f"ios-qa/pr-{pr_number}",
    }


def label_bootstrap(slots: Sequence[dict]) -> list[dict]:
    """Return a JSON-serialisable list of label specs."""
    items: list[dict] = []
    for slot in slots:
        items.append(
            {
                "name": slot["label"],
                "color": "0E8A16",
                "description": f"iOS QA build slot {slot['slot'][2:]}",
            },
        )
    items.append(
        {
            "name": LABEL_BUILDING,
            "color": "FBCA04",
            "description": "iOS QA build is running",
        },
    )
    items.append(
        {
            "name": LABEL_READY,
            "color": "0E8A16",
            "description": "iOS QA build is ready for testing",
        },
    )
    items.append(
        {
            "name": LABEL_QUEUED,
            "color": "D4C5F9",
            "description": "iOS QA build is waiting for a slot",
        },
    )
    items.append(
        {
            "name": LABEL_FAILED,
            "color": "D93F0B",
            "description": "iOS QA build failed",
        },
    )
    items.append(
        {
            "name": NEEDS_QA_LABEL,
            "color": "5319E7",
            "description": "Build this draft PR for iOS QA",
        },
    )
    return items


def resolve_notify_status(
    *,
    stale: bool,
    firebase_distribution_json_exists: bool,
    firebase_links_json: Optional[dict[str, Any]],
) -> dict[str, Optional[str]]:
    if stale:
        return {"status": "stale", "firebase_json": None}
    testing_uri = (
        extract_firebase_testing_uri(firebase_links_json)
        if isinstance(firebase_links_json, dict)
        else None
    )
    if firebase_distribution_json_exists and testing_uri:
        return {"status": "ready", "firebase_json": "firebase-distribution.json"}
    return {"status": "failed", "firebase_json": None}


# --------------------------------------------------------------------------
# GitHub API helpers (kept minimal — used by notify-github / upsert-comment)
# --------------------------------------------------------------------------

def _gh_request(
    method: str,
    url: str,
    *,
    token: str,
    body: Optional[dict] = None,
) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        text = resp.read().decode("utf-8")
        if not text:
            return {}
        return json.loads(text)


def _gh_list_issue_comments(
    repo: str,
    issue_number: int,
    *,
    token: str,
) -> list[dict]:
    comments: list[dict] = []
    page = 1
    while True:
        url = (
            f"https://api.github.com/repos/{repo}/issues/{issue_number}/comments"
            f"?per_page=100&page={page}"
        )
        page_data = _gh_request("GET", url, token=token)
        if not isinstance(page_data, list) or not page_data:
            break
        comments.extend(page_data)
        if len(page_data) < 100:
            break
        page += 1
    return comments


def upsert_sticky_comment(
    *,
    repo: str,
    issue_number: int,
    body: str,
    token: str,
    marker_prefix: str = STATE_MARKER_PREFIX,
) -> dict:
    """Find a marker comment and PATCH it, or POST a new one."""
    comments = _gh_list_issue_comments(repo, issue_number, token=token)
    for comment in comments:
        if marker_prefix in (comment.get("body") or ""):
            url = (
                f"https://api.github.com/repos/{repo}/issues/comments/"
                f"{comment['id']}"
            )
            return _gh_request("PATCH", url, token=token, body={"body": body})
    url = f"https://api.github.com/repos/{repo}/issues/{issue_number}/comments"
    return _gh_request("POST", url, token=token, body={"body": body})


def update_pr_labels(
    *,
    repo: str,
    issue_number: int,
    add: Sequence[str] = (),
    remove: Sequence[str] = (),
    token: str,
) -> None:
    if add:
        url = (
            f"https://api.github.com/repos/{repo}/issues/{issue_number}/labels"
        )
        _gh_request("POST", url, token=token, body={"labels": list(add)})
    for label in remove:
        url = (
            f"https://api.github.com/repos/{repo}/issues/{issue_number}/labels/"
            f"{urllib.parse.quote(label)}"
        )
        try:
            _gh_request("DELETE", url, token=token)
        except urllib.error.HTTPError as exc:
            if exc.code != 404:
                raise


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _read_json_file(path: str) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _write_json(payload: Any) -> None:
    sys.stdout.write(json.dumps(payload, indent=2))
    sys.stdout.write("\n")


def cli_render_label_bootstrap(args: argparse.Namespace) -> int:
    slots = load_slots(args.slots_file)
    _write_json(label_bootstrap(slots))
    return 0


def cli_parse_firebase_distribution(args: argparse.Namespace) -> int:
    payload = _read_json_file(args.json_file)
    uri = extract_firebase_testing_uri(payload)
    if args.require_testing_uri and not uri:
        print(
            "parse-firebase-distribution: testing_uri missing or unsupported "
            "JSON shape (only binary_download_uri is not acceptable)",
            file=sys.stderr,
        )
        return 1
    _write_json({"testing_uri": uri})
    return 0


def cli_render_codemagic_payload(args: argparse.Namespace) -> int:
    pr = _read_json_file(args.pr_json)
    slot = _read_json_file(args.slot_json)
    payload = render_codemagic_payload(
        app_id=args.app_id,
        workflow_id=args.workflow_id,
        branch=args.branch,
        pr=pr,
        slot=slot,
        default_env=args.default_env,
    )
    _write_json(payload)
    return 0


def cli_render_comment(args: argparse.Namespace) -> int:
    firebase_uri: Optional[str] = None
    if args.firebase_json and Path(args.firebase_json).exists():
        firebase_uri = extract_firebase_testing_uri(_read_json_file(args.firebase_json))
    body = render_status_comment(
        status=args.status,
        pr_number=args.pr_number,
        slot=args.slot,
        sha=args.sha,
        codemagic_build_url=args.codemagic_build_url,
        codemagic_build_id=args.codemagic_build_id,
        firebase_testing_uri=firebase_uri,
        failure_reason=args.failure_reason,
        updated_at=args.updated_at,
    )
    sys.stdout.write(body)
    return 0


def cli_render_directory(args: argparse.Namespace) -> int:
    rows = _read_json_file(args.rows_file)
    body = render_directory(rows, updated_at=args.updated_at)
    sys.stdout.write(body)
    return 0


def cli_render_directory_rows(args: argparse.Namespace) -> int:
    reconcile = _read_json_file(args.reconcile_file)
    prs_payload = _read_json_file(args.prs_file)
    prs = {
        int(pr["number"]): pr
        for pr in prs_payload
    }
    _write_json(directory_rows_from_reconcile(reconcile, prs))
    return 0


def cli_cleanup(args: argparse.Namespace) -> int:
    labels = _read_json_file(args.labels_json) if args.labels_json else []
    payload = cleanup_for_closed_pr(pr_number=args.pr_number, labels=labels)
    _write_json(payload)
    return 0


def cli_parse_comment_state(args: argparse.Namespace) -> int:
    body = Path(args.body_file).read_text(encoding="utf-8")
    state = parse_state_marker(body)
    _write_json(state or {})
    return 0


def _eligible_for_slot(
    pr: dict,
    *,
    preserve_labeled_occupants: bool = False,
) -> bool:
    if pr.get("is_closed"):
        return False
    labels = pr.get("labels", [])
    if not is_trusted_pr(
        pr.get("head_repo_owner", ""),
        author_is_org_member=bool(pr.get("author_is_org_member")),
    ):
        return False
    if not is_eligible_pr(
        is_draft=bool(pr.get("is_draft")),
        labels=labels,
    ):
        return False
    if relevant_changes(pr.get("changed_files", [])):
        return True
    return preserve_labeled_occupants and current_slot(labels) is not None


def allocate_for_target(
    *,
    slots: Sequence[dict],
    prs: Sequence[dict],
    target_number: int,
    target_labels_fallback: Sequence[str] = (),
) -> dict:
    """Compute the action for one PR given the full open-PR context.

    Returns a dict with at least ``action`` (``allocate``/``skip``/``cleanup``).
    On ``allocate`` includes ``status`` (building/queued) and ``slot``.
    On ``cleanup`` includes ``labels_to_remove`` and ``mirror_branch``.
    On ``skip`` includes ``reason``.
    """
    target = next((p for p in prs if p["number"] == target_number), None)
    if target is None:
        # PR not in open list — treat as closed for cleanup purposes.
        return {
            "action": "cleanup",
            **cleanup_for_closed_pr(
                pr_number=target_number,
                labels=list(target_labels_fallback),
            ),
        }

    labels = target.get("labels", [])
    is_closed = bool(target.get("is_closed"))
    has_changes = relevant_changes(target.get("changed_files", []))
    action = decide_action(
        is_closed=is_closed,
        has_relevant_changes=has_changes,
        labels=labels,
    )

    if action == "cleanup":
        return {
            "action": "cleanup",
            **cleanup_for_closed_pr(pr_number=target_number, labels=labels),
        }
    if action == "skip":
        return {"action": "skip", "reason": "no relevant changes"}

    # action == 'allocate' — gate on trust + eligibility before competing.
    if not is_trusted_pr(
        target.get("head_repo_owner", ""),
        author_is_org_member=bool(target.get("author_is_org_member")),
    ):
        return {"action": "skip", "reason": "not trusted"}
    if not is_eligible_pr(
        is_draft=bool(target.get("is_draft")),
        labels=labels,
    ):
        return {"action": "skip", "reason": "draft without needs-ios-qa label"}

    candidates = [
        {
            "number": p["number"],
            "labels": p.get("labels", []),
            "eligibility_at": p.get("eligibility_at", ""),
        }
        for p in prs
        if _eligible_for_slot(p, preserve_labeled_occupants=True)
    ]
    assignments = choose_slot(slots, candidates)
    slot_id = assignments.get(target_number, "queued")
    if slot_id == "queued":
        return {
            "action": "allocate",
            "status": "queued",
            "slot": None,
            "labels_to_remove": slot_labels_to_remove(labels),
        }
    slot = next(s for s in slots if s["slot"] == slot_id)
    return {
        "action": "allocate",
        "status": "building",
        "slot": slot,
        "labels_to_remove": slot_labels_to_remove(
            labels,
            keep_label=slot["label"],
        ),
    }


def cli_allocate(args: argparse.Namespace) -> int:
    slots = load_slots(args.slots_file)
    prs = _read_json_file(args.prs_file)
    fallback_labels = (
        args.target_labels.split(",") if args.target_labels else ()
    )
    payload = allocate_for_target(
        slots=slots,
        prs=prs,
        target_number=args.target_number,
        target_labels_fallback=fallback_labels,
    )
    _write_json(payload)
    return 0


def reconcile_assignments(
    *,
    slots: Sequence[dict],
    prs: Sequence[dict],
) -> dict[int, dict]:
    """Compute slot assignments across all open PRs."""
    candidates = [
        {
            "number": p["number"],
            "labels": p.get("labels", []),
            "eligibility_at": p.get("eligibility_at", ""),
        }
        for p in prs
        if _eligible_for_slot(p)
    ]
    assignments = choose_slot(slots, candidates)
    enriched: dict[int, dict] = {}
    for pr in prs:
        n = pr["number"]
        slot_id = assignments.get(n)
        if slot_id is None:
            # PR not eligible for a slot. Determine cleanup vs skip.
            has_qa = _has_qa_label(pr.get("labels", []))
            if has_qa or pr.get("is_closed"):
                enriched[n] = {
                    "action": "cleanup",
                    **cleanup_for_closed_pr(
                        pr_number=n,
                        labels=pr.get("labels", []),
                    ),
                }
            else:
                enriched[n] = {"action": "skip"}
        elif slot_id == "queued":
            enriched[n] = {
                "action": "allocate",
                "status": "queued",
                "slot": None,
                "labels_to_remove": slot_labels_to_remove(pr.get("labels", [])),
            }
        else:
            slot = next(s for s in slots if s["slot"] == slot_id)
            enriched[n] = {
                "action": "allocate",
                "status": "building",
                "slot": slot,
                "labels_to_remove": slot_labels_to_remove(
                    pr.get("labels", []),
                    keep_label=slot["label"],
                ),
            }
    return enriched


def cli_reconcile(args: argparse.Namespace) -> int:
    slots = load_slots(args.slots_file)
    prs = _read_json_file(args.prs_file)
    enriched = reconcile_assignments(slots=slots, prs=prs)
    _write_json({str(k): v for k, v in enriched.items()})
    return 0


def cli_resolve_notify_status(args: argparse.Namespace) -> int:
    stale = args.stale or (
        bool(args.stale_env)
        and os.environ.get(args.stale_env, "").lower() == "true"
    )
    firebase_path = Path(args.firebase_json)
    links_path = Path(args.firebase_links_json)
    links_json: Optional[dict[str, Any]] = None
    if links_path.exists() and links_path.stat().st_size > 0:
        payload = _read_json_file(str(links_path))
        if isinstance(payload, dict):
            links_json = payload
    payload = resolve_notify_status(
        stale=stale,
        firebase_distribution_json_exists=(
            firebase_path.exists() and firebase_path.stat().st_size > 0
        ),
        firebase_links_json=links_json,
    )
    _write_json(payload)
    return 0


def cli_upsert_comment(args: argparse.Namespace) -> int:
    token = os.environ.get(args.token_env)
    if not token:
        print(
            f"upsert-comment: missing {args.token_env} in environment",
            file=sys.stderr,
        )
        return 1
    body = Path(args.body_file).read_text(encoding="utf-8")
    upsert_sticky_comment(
        repo=args.repo,
        issue_number=args.issue_number,
        body=body,
        token=token,
        marker_prefix=args.marker_prefix,
    )
    return 0


def cli_notify_github(args: argparse.Namespace) -> int:
    token = os.environ.get(args.token_env)
    if not token:
        print(
            f"notify-github: missing {args.token_env} in environment",
            file=sys.stderr,
        )
        return 1
    body = Path(args.body_file).read_text(encoding="utf-8")
    upsert_sticky_comment(
        repo=args.repo,
        issue_number=args.issue_number,
        body=body,
        token=token,
    )
    add: list[str] = []
    remove: list[str] = []
    if args.status == "ready":
        add.append(LABEL_READY)
        remove.append(LABEL_BUILDING)
    elif args.status == "failed":
        add.append(LABEL_FAILED)
        remove.append(LABEL_BUILDING)
    elif args.status == "stale":
        # Stale: keep slot label, remove building/ready/failed
        remove.extend([LABEL_BUILDING, LABEL_READY, LABEL_FAILED])
    update_pr_labels(
        repo=args.repo,
        issue_number=args.issue_number,
        add=add,
        remove=remove,
        token=token,
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ios_qa_slots")
    sub = parser.add_subparsers(dest="command", required=True)

    p_labels = sub.add_parser("render-label-bootstrap")
    p_labels.add_argument("--slots-file", required=True)
    p_labels.set_defaults(func=cli_render_label_bootstrap)

    p_fb = sub.add_parser("parse-firebase-distribution")
    p_fb.add_argument("--json-file", required=True)
    p_fb.add_argument("--require-testing-uri", action="store_true")
    p_fb.set_defaults(func=cli_parse_firebase_distribution)

    p_cm = sub.add_parser("render-codemagic-payload")
    p_cm.add_argument("--app-id", required=True)
    p_cm.add_argument("--workflow-id", required=True)
    p_cm.add_argument("--branch", required=True)
    p_cm.add_argument("--pr-json", required=True)
    p_cm.add_argument("--slot-json", required=True)
    p_cm.add_argument("--default-env", default="STAGING")
    p_cm.set_defaults(func=cli_render_codemagic_payload)

    p_comment = sub.add_parser("render-comment")
    p_comment.add_argument("--status", required=True)
    p_comment.add_argument("--pr-number", required=True, type=int)
    p_comment.add_argument("--slot")
    p_comment.add_argument("--sha", required=True)
    p_comment.add_argument("--codemagic-build-url")
    p_comment.add_argument("--codemagic-build-id")
    p_comment.add_argument("--firebase-json")
    p_comment.add_argument("--failure-reason")
    p_comment.add_argument("--updated-at")
    p_comment.set_defaults(func=cli_render_comment)

    p_dir = sub.add_parser("render-directory")
    p_dir.add_argument("--rows-file", required=True)
    p_dir.add_argument("--updated-at", required=True)
    p_dir.set_defaults(func=cli_render_directory)

    p_dir_rows = sub.add_parser("render-directory-rows")
    p_dir_rows.add_argument("--reconcile-file", required=True)
    p_dir_rows.add_argument("--prs-file", required=True)
    p_dir_rows.set_defaults(func=cli_render_directory_rows)

    p_clean = sub.add_parser("cleanup")
    p_clean.add_argument("--pr-number", required=True, type=int)
    p_clean.add_argument("--labels-json")
    p_clean.set_defaults(func=cli_cleanup)

    p_parse_state = sub.add_parser("parse-comment-state")
    p_parse_state.add_argument("--body-file", required=True)
    p_parse_state.set_defaults(func=cli_parse_comment_state)

    p_alloc = sub.add_parser("allocate")
    p_alloc.add_argument("--prs-file", required=True)
    p_alloc.add_argument("--slots-file", required=True)
    p_alloc.add_argument("--target-number", required=True, type=int)
    p_alloc.add_argument(
        "--target-labels",
        help="Comma-separated labels used for cleanup if target PR is missing.",
    )
    p_alloc.set_defaults(func=cli_allocate)

    p_recon = sub.add_parser("reconcile")
    p_recon.add_argument("--prs-file", required=True)
    p_recon.add_argument("--slots-file", required=True)
    p_recon.set_defaults(func=cli_reconcile)

    p_notify_status = sub.add_parser("resolve-notify-status")
    p_notify_status.add_argument(
        "--firebase-json",
        default="firebase-distribution.json",
    )
    p_notify_status.add_argument(
        "--firebase-links-json",
        default="firebase-distribution-links.json",
    )
    p_notify_status.add_argument("--stale", action="store_true")
    p_notify_status.add_argument("--stale-env")
    p_notify_status.set_defaults(func=cli_resolve_notify_status)

    p_upsert = sub.add_parser("upsert-comment")
    p_upsert.add_argument("--repo", required=True)
    p_upsert.add_argument("--issue-number", required=True, type=int)
    p_upsert.add_argument("--body-file", required=True)
    p_upsert.add_argument("--token-env", default="GITHUB_TOKEN")
    p_upsert.add_argument("--marker-prefix", default=STATE_MARKER_PREFIX)
    p_upsert.set_defaults(func=cli_upsert_comment)

    p_notify = sub.add_parser("notify-github")
    p_notify.add_argument("--repo", required=True)
    p_notify.add_argument("--issue-number", required=True, type=int)
    p_notify.add_argument("--body-file", required=True)
    p_notify.add_argument("--status", required=True)
    p_notify.add_argument("--token-env", default="IOS_QA_GITHUB_TOKEN")
    p_notify.set_defaults(func=cli_notify_github)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
