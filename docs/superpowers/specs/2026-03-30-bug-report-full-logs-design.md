# Bug Report Full Logs Design

**Date:** 2026-03-30
**Status:** Draft
**Author:** Matt Bradley

## Problem

Bug reports submitted from the app include only the first 50 log entries (startup noise). Engineers get no logs relevant to the actual bug. See divine-mobile#2582 for an example: logs cut off at seed_data_preload, nothing about the upload failure the user reported.

Two root causes:
1. `_buildLogsSummary()` in `bug_report_dialog.dart` calls `logs.take(50)` -- oldest first, which is startup
2. The full-log Blossom upload path exists (`BugReportService.sendBugReportToRecipient`) but isn't wired into the Zendesk submission flow

## Design

### New Method: `BugReportService.uploadFullLogs()`

```dart
Future<String?> uploadFullLogs(BugReportData data)
```

- Sanitizes the report data (reuses existing `sanitizeSensitiveData()`)
- Creates the full log file (reuses existing `_createBugReportFile()`, currently private -- make it accessible or extract)
- Uploads via `BlossomUploadService.uploadBugReport()`
- Returns the Blossom URL on success, `null` on any failure
- Never throws -- all failures are logged and return null
- If `BlossomUploadService` is null (not injected), returns null immediately

### Improved Inline Summary: `_buildLogsSummary()`

Current behavior: `logs.take(50)` (first 50 entries, startup noise).

New behavior:
1. Collect all error/warning entries from the full log list, take the last 200
2. Collect the last 50 entries of any level (surrounding context)
3. Merge the two sets, deduplicate by timestamp+message, sort chronologically
4. Format as text lines

This gives engineers the errors that matter plus context about what the user was doing.

### Dialog Flow Change

`BugReportDialog._submit()` updated to:

1. `collectDiagnostics()` -- unchanged, returns up to 5,000 log entries
2. `uploadFullLogs(data)` -- new, best-effort Blossom upload, returns URL or null
3. `_buildLogsSummary(data.recentLogs)` -- rewritten with error/warning prioritization
4. `createStructuredBugReport(...)` -- passes both inline summary and Blossom URL

Steps 2 and 3 are independent and could run concurrently, but sequential is fine given the upload is the slow part and the summary is instant.

### Zendesk Ticket Description Format

`createStructuredBugReport()` gets a new optional parameter: `String? fullLogsUrl`.

When present, the ticket description includes before the inline summary:

```
### Full Diagnostic Logs
View full logs: {url}
```

The inline summary header changes from "Recent Logs (Summary)" to "Recent Logs (errors/warnings + recent context)".

No changes to Zendesk configuration, webhook, or GitHub integration. The ticket description is a plain string -- we're changing what goes into it.

## Files Changed

| File | Change |
|------|--------|
| `mobile/lib/services/bug_report_service.dart` | Add public `uploadFullLogs()` method |
| `mobile/lib/widgets/bug_report_dialog.dart` | Call `uploadFullLogs()`, rewrite `_buildLogsSummary()` |
| `mobile/lib/services/zendesk_support_service.dart` | Add optional `fullLogsUrl` param to `createStructuredBugReport()` |

## Error Handling

- Blossom upload failure: log warning, continue with null URL. Ticket still gets the inline summary.
- Auth not available: skip upload, return null. `BlossomUploadService` requires auth but bug reporters are logged in by definition.
- Upload timeout: `uploadBugReport()` already handles multi-server fallback with timeouts.
- No degradation of existing behavior -- if everything fails, the ticket still gets submitted with an improved inline summary (which is already better than the current first-50-lines).

## Testing

- Unit test for rewritten `_buildLogsSummary`: error/warning prioritization, dedup, chronological ordering, empty logs, all-info-no-errors case
- Unit test for `uploadFullLogs`: success path returns URL, failure path returns null, null BlossomUploadService returns null
- Existing Zendesk integration tests pass unchanged (new param is optional)

## Out of Scope

- Android bug reports not reaching Zendesk (Aleysha's finding) -- separate issue, likely stale SDK version
- Zendesk-to-GitHub template formatting bugs (duplication, auto-reply leak in #2564) -- Zendesk webhook config, not mobile
- The dead `bugReportApiUrl` Worker endpoint in config -- cleanup, not related
