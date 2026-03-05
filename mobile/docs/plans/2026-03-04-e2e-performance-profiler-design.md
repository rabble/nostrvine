# E2E Performance Profiler — Design

## Problem

When debugging performance issues in divine-mobile (e.g. slow feed loads, auth delays), logs are scattered across multiple sources:
- Flutter app logs (test runner stdout / adb logcat)
- Docker container logs per service (keycast, funnelcake-relay, funnelcake-api, blossom, postgres, clickhouse)

There's no unified view. Correlation is done by eyeballing timestamps across separate terminals.

## Key Insight

In the local E2E stack, there is exactly one user (the test). Every log line from every container is caused by the test. We don't need distributed tracing, trace IDs, or correlation tokens. We just need **all logs merged into one timestamp-sorted stream**.

## Design

A host-side tool that runs alongside E2E tests and produces a single merged log file. No app changes. No test changes. No backend changes.

### What It Does

1. Starts `docker compose logs -f --timestamps` for all services
2. Starts `flutter test integration_test/...` and captures its stdout (app logs)
3. When the test finishes, stops log capture
4. Parses timestamps from all sources
5. Merges into a single chronologically sorted file with service labels
6. Writes to `test_reports/<test>_<timestamp>.json`

### Output Format

JSON lines, one per log entry, sorted by timestamp:

```json
{"ts": "2026-03-04T15:30:00.100Z", "source": "app", "line": "[RELAY] subscribe filters=[{kinds:[34236],limit:50}]"}
{"ts": "2026-03-04T15:30:00.200Z", "source": "funnelcake-relay", "line": "REQ sub_abc filters=[{kinds:[34236]}]"}
{"ts": "2026-03-04T15:30:04.500Z", "source": "funnelcake-relay", "line": "EOSE sub_abc 12 events"}
{"ts": "2026-03-04T15:30:04.600Z", "source": "app", "line": "[RELAY] EOSE sub_abc received 12 events in 4400ms"}
{"ts": "2026-03-04T15:30:04.700Z", "source": "keycast", "line": "POST /api/nostr 200 45ms"}
```

JSON lines because:
- Parseable by any tool (jq, python, LLM)
- Streamable (can tail in real-time)
- Each line is self-contained with source attribution

### No Flow Boundaries

The tool does not try to identify "steps" or "phases". An LLM reading the report can identify flows from log content (REQ/EOSE pairs, HTTP request/response, auth sequences). Keeping the tool dumb keeps it reliable.

### Usage

```bash
# New mise task
mise run e2e_profile              # runs e2e_test with profiling, produces report
mise run e2e_profile auth/        # profile specific test directory

# Or manually
local_stack/profile.sh integration_test/auth/session_expiry_test.dart
```

The report is saved to `test_reports/` and can be fed to an LLM for analysis:
"Here's a merged log from a home feed load test. Where is the bottleneck?"

### Implementation

A bash script (`local_stack/profile.sh`) that:
- Uses `docker compose logs -f -t` (the `-t` flag adds timestamps)
- Captures flutter test stdout
- Both write to temp files
- After test completion, a small parser (python or dart) merges by timestamp
- Outputs JSON lines to `test_reports/`

### Timestamp Alignment

Docker containers share the host clock. Flutter test stdout timestamps come from the app's `DateTime.now()` which also uses the host clock (emulator syncs from host). No clock skew expected in local E2E.

### App Log Categories Available

The app already logs structured info via `UnifiedLogger` with categories: `RELAY`, `VIDEO`, `UI`, `AUTH`, `STORAGE`, `API`, `SYSTEM`. These appear in test stdout and provide rich context about what the app is doing.

## What This Enables

- Feed an LLM the merged log and ask "why is the home feed slow?"
- Compare reports across code changes to detect regressions
- Inspect the full request lifecycle: app → relay → clickhouse → app
- Debug auth flows: app → keycast → postgres → app
- No infrastructure changes needed, works with existing E2E stack
