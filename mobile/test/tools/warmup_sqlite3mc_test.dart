// ABOUTME: Tests the sqlite3mc warmup retry wrapper used by Mobile CI (#7197).
// ABOUTME: Pins retry-on-failure and fail-closed after the last attempt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('warmup_sqlite3mc.sh', () {
    late Directory sandbox;
    late String scriptPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('warmup_sqlite3mc_');
      final realScript = File(
        p.join(Directory.current.path, 'scripts', 'ci', 'warmup_sqlite3mc.sh'),
      );
      expect(realScript.existsSync(), isTrue);
      scriptPath = p.join(sandbox.path, 'warmup_sqlite3mc.sh');
      File(scriptPath).writeAsStringSync(realScript.readAsStringSync());
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ProcessResult runWarmup({
      required String command,
      String attempts = '5',
      String sleepSecs = '0',
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          ...Platform.environment,
          'SQLITE3MC_WARMUP_CMD': command,
          'SQLITE3MC_WARMUP_ATTEMPTS': attempts,
          'SQLITE3MC_WARMUP_SLEEP_SECS': sleepSecs,
        },
      );
    }

    test('succeeds on the first attempt without retrying', () {
      final result = runWarmup(command: 'true', attempts: '3');
      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('sqlite3mc warmup succeeded on attempt 1'),
      );
      expect(result.stdout.toString(), isNot(contains('attempt 2/')));
    });

    test('retries a failing command and succeeds later', () {
      final marker = File(p.join(sandbox.path, 'tries'));
      final flaky = File(p.join(sandbox.path, 'flaky.sh'))
        ..writeAsStringSync(r'''
#!/usr/bin/env bash
set -euo pipefail
n=0
if [ -f "$MARKER" ]; then
  n=$(wc -l < "$MARKER")
fi
echo x >> "$MARKER"
test "$n" -ge 2
''');
      final result = Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          ...Platform.environment,
          'MARKER': marker.path,
          'SQLITE3MC_WARMUP_CMD': 'bash ${flaky.path}',
          'SQLITE3MC_WARMUP_ATTEMPTS': '4',
          'SQLITE3MC_WARMUP_SLEEP_SECS': '0',
        },
      );
      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('sqlite3mc warmup succeeded on attempt 3'),
      );
      expect(marker.readAsLinesSync(), hasLength(3));
    });

    test('fails closed after the last attempt', () {
      final result = runWarmup(command: 'false', attempts: '3');
      expect(result.exitCode, equals(1));
      expect(
        result.stderr.toString(),
        contains('sqlite3mc warmup failed after 3 attempts'),
      );
      expect(result.stdout.toString(), contains('attempt 3/3'));
    });

    test('rejects a non-positive attempt count', () {
      final result = runWarmup(command: 'true', attempts: '0');
      expect(result.exitCode, equals(2));
      expect(
        result.stderr.toString(),
        contains('SQLITE3MC_WARMUP_ATTEMPTS must be a positive integer'),
      );
    });
  });
}
