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
      scriptPath = realScript.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ProcessResult runWarmup({
      String? command,
      String attempts = '5',
      String sleepSecs = '0',
      Map<String, String> environment = const {},
    }) {
      final processEnvironment = {
        ...Platform.environment,
        'SQLITE3MC_WARMUP_ATTEMPTS': attempts,
        'SQLITE3MC_WARMUP_SLEEP_SECS': sleepSecs,
        ...environment,
      };
      if (command != null) {
        processEnvironment['SQLITE3MC_WARMUP_CMD'] = command;
      }

      return Process.runSync(
        'bash',
        [scriptPath],
        environment: processEnvironment,
      );
    }

    test('runs the default warmup command from the real project root', () {
      final fakeBin = Directory(p.join(sandbox.path, 'bin'))..createSync();
      final capture = File(p.join(sandbox.path, 'capture.txt'));
      final fakeDart = File(p.join(fakeBin.path, 'dart'))
        ..writeAsStringSync('''
#!/usr/bin/env bash
set -euo pipefail
{
  pwd
  printf '%s\\n' "\$@"
} > "${capture.path}"
''');
      final chmod = Process.runSync('chmod', ['755', fakeDart.path]);
      expect(chmod.exitCode, equals(0), reason: chmod.stderr.toString());

      final result = runWarmup(
        attempts: '1',
        environment: {
          'PATH': '${fakeBin.path}:${Platform.environment['PATH']}',
        },
      );

      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(
        capture.readAsLinesSync(),
        equals([
          Directory.current.path,
          'run',
          'tools/warmup_sqlite3mc.dart',
        ]),
      );
    });

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

    test('rejects an invalid sleep duration', () {
      final result = runWarmup(command: 'true', sleepSecs: '-1');
      expect(result.exitCode, equals(2));
      expect(
        result.stderr.toString(),
        contains('SQLITE3MC_WARMUP_SLEEP_SECS must be a non-negative integer'),
      );
    });
  });
}
