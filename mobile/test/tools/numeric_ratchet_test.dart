// ABOUTME: Tests for the shared numeric per-key ceiling engine (scripts/lib/numeric_ratchet.sh)
// ABOUTME: Drives the lib via a probe script against temp fixtures: pass/growth/new/stale/decrease

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exercises `scripts/lib/numeric_ratchet.sh` in isolation through a tiny probe
/// script whose `emit_current` reads a fixture file. Pins the engine contract
/// shared by the service-sentinel and ARB-{error} ceilings (epic #4336).
void main() {
  group('numeric_ratchet engine', () {
    late Directory tmp;
    late String libPath;
    late File current;
    late File baseline;
    late File probe;

    void writeCurrent(String body) => current.writeAsStringSync(body);

    ProcessResult run({bool update = false}) {
      return Process.runSync(
        'bash',
        [probe.path],
        environment: {
          'PROBE_MOBILE': '${tmp.path}/m',
          'PROBE_BASELINE': baseline.path,
          'PROBE_CURRENT': current.path,
          'PROBE_LIB': libPath,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('numeric_ratchet_test');
      Directory('${tmp.path}/m').createSync(recursive: true);
      libPath = File('scripts/lib/numeric_ratchet.sh').absolute.path;
      current = File('${tmp.path}/current.txt');
      baseline = File('${tmp.path}/baseline.txt');
      probe = File('${tmp.path}/probe.sh');
      probe.writeAsStringSync(r'''
#!/usr/bin/env bash
set -euo pipefail
MOBILE_DIR="$PROBE_MOBILE"
RATCHET_LABEL="probe"
BASELINE_FILE="$PROBE_BASELINE"
BASELINE_REPO_PATH="mobile/scripts/baseline/__probe_nonexistent__.txt"
BASE_REF="origin/main"
ALLOW_NO_BASE=1
ALLOW_NO_BASE_VAR="PROBE_ALLOW_NO_BASE"
NEW_HINT="new-hint"
STALE_HINT="stale-hint"
FOOTER="footer"
emit_current() { cat "$PROBE_CURRENT"; }
print_baseline_header() { echo "# probe baseline"; }
source "$PROBE_LIB"
run_numeric_ratchet
''');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('UPDATE_BASELINE freezes the current key/count set', () {
      writeCurrent('a\t5\nb\t3\n');
      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());
      final entries = baseline
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(entries, hasLength(2));
    });

    test('passes when counts are unchanged', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [probe]'));
    });

    test('fails when a key count grows', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t6\nb\t3\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW'));
    });

    test('fails when a new key appears', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t5\nb\t3\nc\t1\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW key'));
    });

    test('fails (stale) when a baselined key disappears', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t5\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer emitted'));
    });

    test('passes when a count decreases (low friction)', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t4\nb\t3\n');
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [probe]'));
    });
  });
}
