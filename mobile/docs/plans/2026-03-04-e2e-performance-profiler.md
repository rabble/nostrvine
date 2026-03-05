# E2E Performance Profiler Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A host-side bash script that runs E2E tests while capturing all Docker + app logs, then merges them into a single timestamp-sorted JSON lines file for LLM analysis.

**Architecture:** A bash wrapper (`local_stack/profile.sh`) captures docker compose logs and flutter test stdout in parallel to temp files. After the test finishes, a Python script parses timestamps from both sources (Docker RFC3339 format, app log ISO8601 format) and merges into sorted JSON lines. A mise task provides the ergonomic entry point.

**Tech Stack:** Bash (orchestration), Python 3 (log parser/merger), mise (task runner)

---

### Task 1: Create the log merger script

**Files:**
- Create: `local_stack/merge_logs.py`

**Step 1: Write the merger script**

This Python script reads two log files (docker logs + app logs), parses timestamps, and outputs sorted JSON lines.

Docker log format (with `-t` flag and `--no-log-prefix` per service):
```
2026-03-04T13:11:56.516035573Z {"timestamp":"...","level":"ERROR","fields":{"message":"..."}}
```

When using `docker compose logs -t` (all services), each line is prefixed:
```
keycast-1  | 2026-03-04T13:11:56.516035573Z <content>
```

App log format (debugPrint from flutter test stdout):
```
Phase 1 complete: user registered and authenticated
```
App logs from UnifiedLogger (via adb logcat or test stdout):
```
[2026-03-04T15:30:00.100] [INFO] [nostr_client] RELAY: subscribe filters=[...]
```

```python
#!/usr/bin/env python3
"""Merge docker compose logs and flutter test output into sorted JSON lines."""

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Docker compose log line: "service-1  | 2026-03-04T13:11:56.516035573Z content"
DOCKER_RE = re.compile(
    r'^(\S+)\s+\|\s+'           # service name + pipe
    r'(\d{4}-\d{2}-\d{2}T'     # timestamp start
    r'\d{2}:\d{2}:\d{2}'       # HH:MM:SS
    r'(?:\.\d+)?Z?)\s*'        # optional fractional seconds + Z
    r'(.*)'                     # content
)

# App log with timestamp: "[2026-03-04T15:30:00.100] [LEVEL] ..."
APP_TS_RE = re.compile(
    r'^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]\s*(.*)'
)


def parse_ts(ts_str: str) -> datetime:
    """Parse various timestamp formats to datetime."""
    # Truncate nanoseconds to microseconds for Python
    ts_str = re.sub(r'(\.\d{6})\d+', r'\1', ts_str)
    ts_str = ts_str.rstrip('Z')
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S'):
        try:
            return datetime.strptime(ts_str, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    raise ValueError(f'Cannot parse timestamp: {ts_str}')


def parse_docker_logs(path: Path) -> list[dict]:
    """Parse docker compose log file into structured entries."""
    entries = []
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        m = DOCKER_RE.match(line)
        if m:
            service = m.group(1).rsplit('-', 1)[0]  # "keycast-1" -> "keycast"
            try:
                ts = parse_ts(m.group(2))
            except ValueError:
                continue
            entries.append({
                'ts': ts.isoformat() + 'Z',
                'source': service,
                'line': m.group(3).strip(),
            })
    return entries


def parse_app_logs(path: Path) -> list[dict]:
    """Parse flutter test stdout into structured entries."""
    entries = []
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        m = APP_TS_RE.match(line)
        if m:
            try:
                ts = parse_ts(m.group(1))
            except ValueError:
                continue
            entries.append({
                'ts': ts.isoformat() + 'Z',
                'source': 'app',
                'line': m.group(2).strip(),
            })
        else:
            # Lines without timestamps get tagged as app output
            entries.append({
                'ts': '',
                'source': 'app',
                'line': line.strip(),
            })
    return entries


def main():
    if len(sys.argv) < 3:
        print(f'Usage: {sys.argv[0]} <docker_log> <app_log> [output]',
              file=sys.stderr)
        sys.exit(1)

    docker_path = Path(sys.argv[1])
    app_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    docker_entries = parse_docker_logs(docker_path)
    app_entries = parse_app_logs(app_path)

    # Merge and sort by timestamp (entries without timestamps go to end)
    all_entries = docker_entries + app_entries
    all_entries.sort(key=lambda e: e['ts'] if e['ts'] else 'z')

    lines = [json.dumps(e) for e in all_entries]
    output = '\n'.join(lines) + '\n'

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output)
        print(f'Wrote {len(all_entries)} entries to {output_path}',
              file=sys.stderr)
    else:
        sys.stdout.write(output)


if __name__ == '__main__':
    main()
```

**Step 2: Make it executable and test with existing docker logs**

Run:
```bash
chmod +x local_stack/merge_logs.py
docker compose -f local_stack/docker-compose.yml logs -t --tail=20 > /tmp/docker_test.log
echo '[2026-03-04T15:30:00.100] [INFO] test line' > /tmp/app_test.log
python3 local_stack/merge_logs.py /tmp/docker_test.log /tmp/app_test.log | head -5
```
Expected: JSON lines with `ts`, `source`, `line` fields, sorted by timestamp.

**Step 3: Commit**

```bash
git add local_stack/merge_logs.py
git commit -m "feat: add log merger script for E2E performance profiling"
```

---

### Task 2: Create the profiler wrapper script

**Files:**
- Create: `local_stack/profile.sh`

**Step 1: Write the wrapper script**

This bash script orchestrates the whole flow: starts docker log capture, runs the E2E test, stops capture, merges logs.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# E2E Performance Profiler
# Captures docker + app logs during a test run, merges into sorted JSON lines.
#
# Usage:
#   local_stack/profile.sh [test_path]
#   local_stack/profile.sh integration_test/auth/session_expiry_test.dart
#   local_stack/profile.sh integration_test/auth/   (whole directory)
#
# Default: integration_test/auth/
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../mobile" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
MERGE_SCRIPT="${SCRIPT_DIR}/merge_logs.py"

TEST_PATH="${1:-integration_test/auth/}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="${MOBILE_DIR}/test_reports"
REPORT_FILE="${REPORT_DIR}/${TIMESTAMP}.jsonl"

TMPDIR="$(mktemp -d)"
DOCKER_LOG="${TMPDIR}/docker.log"
APP_LOG="${TMPDIR}/app.log"

cleanup() {
    # Stop docker log capture if running
    if [[ -n "${DOCKER_PID:-}" ]] && kill -0 "$DOCKER_PID" 2>/dev/null; then
        kill "$DOCKER_PID" 2>/dev/null || true
        wait "$DOCKER_PID" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "=== E2E Performance Profiler ===" >&2
echo "Test path:  ${TEST_PATH}" >&2
echo "Report:     ${REPORT_FILE}" >&2
echo "" >&2

# Verify docker stack is running
if ! docker compose -f "$COMPOSE_FILE" ps --status running -q 2>/dev/null | head -1 | grep -q .; then
    echo "ERROR: Docker stack is not running. Start with: mise run local_up" >&2
    exit 1
fi

# Start docker log capture (background)
echo "Starting docker log capture..." >&2
docker compose -f "$COMPOSE_FILE" logs -f -t \
    keycast funnelcake-relay funnelcake-api blossom \
    > "$DOCKER_LOG" 2>&1 &
DOCKER_PID=$!

# Get connected device
DEVICE="$(adb devices | sed -n '2p' | cut -f1)"
if [[ -z "$DEVICE" ]]; then
    echo "ERROR: No Android device connected." >&2
    exit 1
fi

# Run E2E test, capture stdout+stderr
echo "Running tests: flutter test ${TEST_PATH} ..." >&2
cd "$MOBILE_DIR"
flutter test "$TEST_PATH" \
    --dart-define=DEFAULT_ENV=LOCAL \
    -d "$DEVICE" \
    2>&1 | tee "$APP_LOG"
TEST_EXIT=$?

# Stop docker log capture
kill "$DOCKER_PID" 2>/dev/null || true
wait "$DOCKER_PID" 2>/dev/null || true

# Merge logs
echo "" >&2
echo "Merging logs..." >&2
python3 "$MERGE_SCRIPT" "$DOCKER_LOG" "$APP_LOG" "$REPORT_FILE"

echo "" >&2
if [[ $TEST_EXIT -eq 0 ]]; then
    echo "Tests PASSED. Report: ${REPORT_FILE}" >&2
else
    echo "Tests FAILED (exit $TEST_EXIT). Report: ${REPORT_FILE}" >&2
fi

exit $TEST_EXIT
```

**Step 2: Make it executable and do a dry run**

```bash
chmod +x local_stack/profile.sh
```

Verify the script parses correctly (no syntax errors):
```bash
bash -n local_stack/profile.sh
```

**Step 3: Commit**

```bash
git add local_stack/profile.sh
git commit -m "feat: add profiler wrapper script for E2E test runs"
```

---

### Task 3: Add mise task and gitignore for reports

**Files:**
- Modify: `mobile/mise.toml`
- Create: `mobile/test_reports/.gitkeep`
- Modify: `mobile/.gitignore` (if exists) or create `mobile/test_reports/.gitignore`

**Step 1: Add the mise task**

Add to `mobile/mise.toml`:

```toml
[tasks.e2e_profile]
description = "Run E2E tests with performance profiling (merged log report)"
run = "bash ../local_stack/profile.sh {{ arg(i=0, name='test_path', default='integration_test/auth/') }}"
```

**Step 2: Create test_reports directory with gitignore**

```bash
mkdir -p mobile/test_reports
echo '*.jsonl' > mobile/test_reports/.gitignore
echo '!.gitignore' >> mobile/test_reports/.gitignore
```

This keeps the directory in git but ignores report files.

**Step 3: Commit**

```bash
git add mobile/mise.toml mobile/test_reports/.gitignore
git commit -m "feat: add e2e_profile mise task and test_reports directory"
```

---

### Task 4: Run a real profiled E2E test and verify the report

**Step 1: Ensure docker stack is running**

```bash
cd mobile && mise run local_status
```

If not running:
```bash
mise run local_up
```

**Step 2: Run the profiler against a single test**

```bash
mise run e2e_profile integration_test/auth/email_registration_test.dart
```

**Step 3: Verify the report**

```bash
# Check the report exists
ls -la mobile/test_reports/*.jsonl

# Check it has content from multiple sources
cat mobile/test_reports/*.jsonl | python3 -c "
import json, sys, collections
sources = collections.Counter()
for line in sys.stdin:
    e = json.loads(line)
    sources[e['source']] += 1
for s, c in sources.most_common():
    print(f'{s}: {c} lines')
"
```

Expected: entries from `app`, `keycast`, `funnelcake-relay`, and possibly `funnelcake-api` and `blossom`.

**Step 4: Verify the report is LLM-consumable**

```bash
head -20 mobile/test_reports/*.jsonl
```

Each line should be valid JSON with `ts`, `source`, `line` fields, sorted chronologically.

**Step 5: Commit if any tweaks were needed**

```bash
git add -p  # review any fixes
git commit -m "fix: adjust log parsing for actual output formats"
```

---

### Summary

| Task | What | Files |
|------|------|-------|
| 1 | Log merger (Python) | `local_stack/merge_logs.py` |
| 2 | Profiler wrapper (Bash) | `local_stack/profile.sh` |
| 3 | Mise task + gitignore | `mobile/mise.toml`, `mobile/test_reports/.gitignore` |
| 4 | End-to-end verification | Run real test, verify report |

Total: ~150 lines of Python, ~60 lines of Bash, 2 lines of TOML.
