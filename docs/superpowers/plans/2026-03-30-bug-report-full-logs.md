# Bug Report Full Logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Include full diagnostic logs (uploaded to Blossom) and an improved inline summary (errors/warnings + recent context) in bug reports submitted to Zendesk.

**Architecture:** Add `uploadFullLogs()` to `BugReportService` (sanitize, create file, upload to Blossom, return URL). Rewrite `_buildLogsSummary()` in the dialog to prioritize errors/warnings. Pass both the URL and improved summary to `createStructuredBugReport()`.

**Tech Stack:** Dart/Flutter, Zendesk SDK, Blossom upload (existing), mocktail for tests

**Spec:** `docs/superpowers/specs/2026-03-30-bug-report-full-logs-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `mobile/lib/services/bug_report_service.dart` | Modify | Add `uploadFullLogs()` public method |
| `mobile/lib/widgets/bug_report_dialog.dart` | Modify | Wire upload, rewrite `_buildLogsSummary()` |
| `mobile/lib/services/zendesk_support_service.dart` | Modify | Add `fullLogsUrl` param |
| `mobile/test/unit/services/bug_report_service_upload_logs_test.dart` | Create | Tests for `uploadFullLogs()` |
| `mobile/test/widgets/bug_report_dialog_log_summary_test.dart` | Create | Tests for rewritten `_buildLogsSummary()` |

---

### Task 1: Add `uploadFullLogs()` to BugReportService

**Files:**
- Modify: `mobile/lib/services/bug_report_service.dart`
- Create: `mobile/test/unit/services/bug_report_service_upload_logs_test.dart`

- [ ] **Step 1: Write tests for `uploadFullLogs()`**

Create `mobile/test/unit/services/bug_report_service_upload_logs_test.dart`:

```dart
// ABOUTME: Tests for BugReportService.uploadFullLogs()
// ABOUTME: Verifies Blossom upload success, failure fallback, and null service handling

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData, LogEntry, LogLevel;
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group('BugReportService.uploadFullLogs', () {
    late _MockBlossomUploadService mockBlossom;

    setUp(() {
      mockBlossom = _MockBlossomUploadService();
      registerFallbackValue(File(''));
    });

    BugReportData _makeReportData({int logCount = 5}) {
      return BugReportData(
        reportId: 'test-123',
        timestamp: DateTime(2026, 3, 30),
        userDescription: 'Upload failed',
        deviceInfo: {'platform': 'ios', 'version': '18.0'},
        appVersion: '1.0.7+602',
        recentLogs: List.generate(
          logCount,
          (i) => LogEntry(
            timestamp: DateTime(2026, 3, 30, 10, 0, i),
            level: i % 3 == 0 ? LogLevel.error : LogLevel.info,
            message: 'Log entry $i',
          ),
        ),
        errorCounts: {'upload_failed': 2},
      );
    }

    test('returns Blossom URL on successful upload', () async {
      when(() => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          )).thenAnswer((_) async =>
          'https://media.divine.video/abc123.txt');

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = _makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, 'https://media.divine.video/abc123.txt');
      verify(() => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          )).called(1);
    });

    test('returns null when Blossom upload fails', () async {
      when(() => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          )).thenAnswer((_) async => null);

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = _makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });

    test('returns null when Blossom upload throws', () async {
      when(() => mockBlossom.uploadBugReport(
            bugReportFile: any(named: 'bugReportFile'),
          )).thenThrow(Exception('network error'));

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = _makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });

    test('returns null when BlossomUploadService is null', () async {
      final service = BugReportService();
      final data = _makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test test/unit/services/bug_report_service_upload_logs_test.dart`

Expected: Compilation error -- `uploadFullLogs` not defined on `BugReportService`.

- [ ] **Step 3: Implement `uploadFullLogs()` on BugReportService**

In `mobile/lib/services/bug_report_service.dart`, add this method after `collectDiagnostics()` (after line ~162):

```dart
  /// Upload full diagnostic logs to Blossom server.
  /// Returns the Blossom URL on success, null on any failure.
  /// Best-effort: failures are logged and return null, never throws.
  Future<String?> uploadFullLogs(BugReportData data) async {
    if (_blossomUploadService == null) {
      Log.debug(
        'BlossomUploadService not available, skipping full log upload',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      final sanitizedData = sanitizeSensitiveData(data);
      final file = await _createBugReportFile(sanitizedData);
      final url = await _blossomUploadService.uploadBugReport(
        bugReportFile: file,
      );

      if (url != null) {
        Log.info(
          'Full logs uploaded to Blossom: $url',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Blossom upload returned null, continuing without full logs URL',
          category: LogCategory.system,
        );
      }

      return url;
    } catch (e, stackTrace) {
      Log.warning(
        'Failed to upload full logs to Blossom: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test test/unit/services/bug_report_service_upload_logs_test.dart`

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/mjb/code/divine-mobile && git add mobile/lib/services/bug_report_service.dart mobile/test/unit/services/bug_report_service_upload_logs_test.dart && git commit -m "feat(bug-report): add uploadFullLogs() for Blossom upload of diagnostics"
```

---

### Task 2: Add `fullLogsUrl` parameter to `createStructuredBugReport()`

**Files:**
- Modify: `mobile/lib/services/zendesk_support_service.dart:837-916`

- [ ] **Step 1: Add `fullLogsUrl` parameter and update ticket description**

In `mobile/lib/services/zendesk_support_service.dart`, modify `createStructuredBugReport()`:

Add parameter to the method signature (after `String? logsSummary,`):

```dart
    String? fullLogsUrl,
```

Then in the description buffer, replace lines 911-916 (the `logsSummary` block) with:

```dart
    if (fullLogsUrl != null) {
      buffer.writeln();
      buffer.writeln('### Full Diagnostic Logs');
      buffer.writeln('View full logs: $fullLogsUrl');
    }
    if (logsSummary != null && logsSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent Logs (errors/warnings + recent context)');
      buffer.writeln('```');
      buffer.writeln(logsSummary);
      buffer.writeln('```');
    }
```

- [ ] **Step 2: Run existing tests to verify nothing breaks**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test test/widgets/bug_report_dialog_test.dart`

Expected: All existing tests PASS (new parameter is optional, no callers break).

- [ ] **Step 3: Commit**

```bash
cd /Users/mjb/code/divine-mobile && git add mobile/lib/services/zendesk_support_service.dart && git commit -m "feat(bug-report): add fullLogsUrl param to createStructuredBugReport"
```

---

### Task 3: Rewrite `_buildLogsSummary()` in BugReportDialog

**Files:**
- Modify: `mobile/lib/widgets/bug_report_dialog.dart:136-140`
- Create: `mobile/test/widgets/bug_report_dialog_log_summary_test.dart`

- [ ] **Step 1: Extract `_buildLogsSummary` to a visible function for testing**

The current `_buildLogsSummary` is a private method on `_BugReportDialogState`. To test it without widget boilerplate, extract it as a top-level function in the same file. In `mobile/lib/widgets/bug_report_dialog.dart`, replace lines 136-140:

```dart
  String? _buildLogsSummary(List<LogEntry> logs) {
    if (logs.isEmpty) return null;
    final recentLines = logs.take(50).map((log) => log.toFormattedString());
    return recentLines.join('\n');
  }
```

with a call to the new top-level function:

```dart
  String? _buildLogsSummary(List<LogEntry> logs) => buildLogsSummary(logs);
```

Add the top-level function before the class definition (after the imports, before line 17):

```dart
/// Build a log summary prioritizing errors/warnings with recent context.
/// Returns null if logs are empty.
/// Takes up to 200 most recent error/warning entries plus the last 50
/// entries of any level, deduplicates, and sorts chronologically.
String? buildLogsSummary(List<LogEntry> logs) {
  if (logs.isEmpty) return null;

  // Last 200 error/warning entries
  final errorWarnings = logs
      .where((l) => l.level == LogLevel.error || l.level == LogLevel.warning)
      .toList();
  final recentErrors = errorWarnings.length > 200
      ? errorWarnings.sublist(errorWarnings.length - 200)
      : errorWarnings;

  // Last 50 entries of any level
  final recentContext = logs.length > 50
      ? logs.sublist(logs.length - 50)
      : logs;

  // Merge, deduplicate, sort chronologically
  final merged = <LogEntry>{...recentErrors, ...recentContext}.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return merged.map((log) => log.toFormattedString()).join('\n');
}
```

Also add the `LogLevel` import if not already present. The file already imports `LogEntry` from `models/models.dart` -- check if `LogLevel` is exported there too. If not, add:

```dart
import 'package:models/models.dart' show LogEntry, LogLevel;
```

(Update the existing import on line 10 to include `LogLevel`.)

- [ ] **Step 2: Write tests for the new `buildLogsSummary()`**

Create `mobile/test/widgets/bug_report_dialog_log_summary_test.dart`:

```dart
// ABOUTME: Tests for buildLogsSummary() log prioritization logic
// ABOUTME: Verifies error/warning prioritization, dedup, chronological ordering

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show LogEntry, LogLevel;
import 'package:openvine/widgets/bug_report_dialog.dart';

LogEntry _log(int minute, LogLevel level, String msg) => LogEntry(
      timestamp: DateTime(2026, 3, 30, 10, minute),
      level: level,
      message: msg,
    );

void main() {
  group('buildLogsSummary', () {
    test('returns null for empty logs', () {
      expect(buildLogsSummary([]), isNull);
    });

    test('includes all entries when under limits', () {
      final logs = [
        _log(0, LogLevel.info, 'startup'),
        _log(1, LogLevel.error, 'crash'),
        _log(2, LogLevel.info, 'recovered'),
      ];
      final result = buildLogsSummary(logs)!;
      expect(result, contains('startup'));
      expect(result, contains('crash'));
      expect(result, contains('recovered'));
    });

    test('prioritizes errors/warnings over old info logs', () {
      // 100 info logs, then 5 errors at the end
      final logs = <LogEntry>[
        for (var i = 0; i < 100; i++)
          _log(i, LogLevel.info, 'info-$i'),
        for (var i = 100; i < 105; i++)
          _log(i, LogLevel.error, 'error-$i'),
      ];

      final result = buildLogsSummary(logs)!;

      // All 5 errors should be present
      for (var i = 100; i < 105; i++) {
        expect(result, contains('error-$i'));
      }
      // Old info logs (before last 50) should NOT be present
      expect(result, isNot(contains('info-0')));
      expect(result, isNot(contains('info-10')));
      // Recent info logs (last 50) should be present
      expect(result, contains('info-54'));
      expect(result, contains('info-99'));
    });

    test('deduplicates entries that appear in both sets', () {
      // Error at minute 99 is in both error set and last-50 set
      final logs = <LogEntry>[
        for (var i = 0; i < 100; i++)
          _log(i, LogLevel.info, 'info-$i'),
        _log(99, LogLevel.error, 'recent-error'),
      ];

      final result = buildLogsSummary(logs)!;
      // Should appear exactly once
      final count = 'recent-error'.allMatches(result).length;
      expect(count, 1);
    });

    test('sorts output chronologically', () {
      // Error early, info late -- output should be time-ordered
      final logs = <LogEntry>[
        _log(5, LogLevel.error, 'early-error'),
        for (var i = 10; i < 20; i++)
          _log(i, LogLevel.info, 'late-info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      final earlyIdx = result.indexOf('early-error');
      final lateIdx = result.indexOf('late-info-15');
      expect(earlyIdx, lessThan(lateIdx));
    });

    test('caps error/warning entries at 200', () {
      // 300 warnings + 10 info at the end
      final logs = <LogEntry>[
        for (var i = 0; i < 300; i++)
          _log(i, LogLevel.warning, 'warn-$i'),
        for (var i = 300; i < 310; i++)
          _log(i, LogLevel.info, 'info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      // First 100 warnings should be dropped (only last 200 kept)
      expect(result, isNot(contains('warn-0')));
      expect(result, isNot(contains('warn-99')));
      // warn-100 onward should be present
      expect(result, contains('warn-100'));
      expect(result, contains('warn-299'));
      // Recent info should be present
      expect(result, contains('info-309'));
    });

    test('handles all-error logs', () {
      final logs = <LogEntry>[
        for (var i = 0; i < 10; i++)
          _log(i, LogLevel.error, 'error-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      for (var i = 0; i < 10; i++) {
        expect(result, contains('error-$i'));
      }
    });

    test('handles all-info logs with no errors', () {
      final logs = <LogEntry>[
        for (var i = 0; i < 100; i++)
          _log(i, LogLevel.info, 'info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      // Only last 50 should be present
      expect(result, isNot(contains('info-0')));
      expect(result, contains('info-50'));
      expect(result, contains('info-99'));
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test test/widgets/bug_report_dialog_log_summary_test.dart`

Expected: All 7 tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/mjb/code/divine-mobile && git add mobile/lib/widgets/bug_report_dialog.dart mobile/test/widgets/bug_report_dialog_log_summary_test.dart && git commit -m "feat(bug-report): rewrite log summary to prioritize errors/warnings + recent context"
```

---

### Task 4: Wire everything together in BugReportDialog._submitReport()

**Files:**
- Modify: `mobile/lib/widgets/bug_report_dialog.dart:62-93`

- [ ] **Step 1: Update `_submitReport()` to call `uploadFullLogs()` and pass URL**

Replace the body of `_submitReport()` (lines 62-133) with:

```dart
  Future<void> _submitReport() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
      _isSuccess = null;
    });

    try {
      // Collect diagnostics for device info
      final description = _descriptionController.text.trim();
      final reportData = await widget.bugReportService.collectDiagnostics(
        userDescription: description,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
      );

      // Best-effort: upload full logs to Blossom
      final fullLogsUrl = await widget.bugReportService.uploadFullLogs(
        reportData,
      );

      // Submit directly to Zendesk with structured fields
      final subject = _subjectController.text.trim();
      final success = await ZendeskSupportService.createStructuredBugReport(
        subject: subject,
        description: description,
        stepsToReproduce: _stepsController.text.trim(),
        expectedBehavior: _expectedController.text.trim(),
        reportId: reportData.reportId,
        appVersion: reportData.appVersion,
        deviceInfo: reportData.deviceInfo,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
        errorCounts: reportData.errorCounts,
        logsSummary: _buildLogsSummary(reportData.recentLogs),
        fullLogsUrl: fullLogsUrl,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = success;
          if (success) {
            _resultMessage =
                "Thank you! We've received your report and will use it to make Divine better.";
          } else {
            _resultMessage =
                'Failed to send bug report. Please try again later.';
          }
        });

        // Close dialog after delay if successful
        if (success) {
          _closeTimer = Timer(const Duration(milliseconds: 1500), () {
            if (!_isDisposed && mounted) {
              context.pop();
            }
          });
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error submitting bug report: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _resultMessage = 'Bug report failed to send: $e';
        });
      }
    }
  }
```

The only changes from the original are:
1. Added `final fullLogsUrl = await widget.bugReportService.uploadFullLogs(reportData);` between collectDiagnostics and createStructuredBugReport
2. Added `fullLogsUrl: fullLogsUrl,` to the createStructuredBugReport call

- [ ] **Step 2: Run all related tests**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test test/widgets/bug_report_dialog_test.dart test/widgets/bug_report_dialog_log_summary_test.dart test/unit/services/bug_report_service_upload_logs_test.dart`

Expected: All tests PASS. The existing widget tests mock `BugReportService` via mocktail. The new `uploadFullLogs` call will return null by default (mocktail returns null for unstubbed methods on nullable return types), so existing tests continue to pass without modification.

- [ ] **Step 3: Run the full test suite**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test`

Expected: All tests PASS. No other files were modified.

- [ ] **Step 4: Commit**

```bash
cd /Users/mjb/code/divine-mobile && git add mobile/lib/widgets/bug_report_dialog.dart && git commit -m "feat(bug-report): wire Blossom full-log upload + improved summary into Zendesk path"
```

---

### Task 5: Verify and open draft PR

- [ ] **Step 1: Run full test suite one more time**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter test`

Expected: All tests PASS.

- [ ] **Step 2: Run static analysis**

Run: `cd /Users/mjb/code/divine-mobile/mobile && flutter analyze`

Expected: No errors. Warnings unrelated to our changes are acceptable.

- [ ] **Step 3: Open draft PR**

Target: `main` on `divinevideo/divine-mobile`

Title: `feat(bug-report): upload full diagnostic logs to Blossom and improve inline summary`

Body should reference:
- The problem: first-50-lines truncation (#2582 as example)
- The fix: Blossom upload for full logs + error/warning-prioritized inline summary
- Link to spec: `docs/superpowers/specs/2026-03-30-bug-report-full-logs-design.md`
- Note: Blossom upload is best-effort, failures degrade gracefully to inline summary only
