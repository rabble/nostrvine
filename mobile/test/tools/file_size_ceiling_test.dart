// ABOUTME: Tests for the file-size advisory (scripts/check_file_size_ceiling.sh)
// ABOUTME: Verifies bootstrap, clean pass, growth-warn, new-file-warn, and shrink — all exit 0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_file_size_ceiling.sh` against an isolated temp tree so
/// the per-file advisory logic (epic #4339) is verified without touching the
/// real baseline. The bash script is the source of truth; this test pins its
/// advisory contract: NEW / GROWN files are reported as warnings, but the
/// script ALWAYS exits 0 — it never fails CI.
void main() {
  group('file_size_ceiling advisory', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    File libFile(String name) => File('${tmp.path}/lib/$name');

    // Trailing newline so `wc -l` (which counts newlines) reports exactly [n].
    void writeLines(String name, int n) {
      libFile(
        name,
      ).writeAsStringSync('${List.filled(n, '// line').join('\n')}\n');
    }

    ProcessResult run({bool update = false}) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'FILE_SIZE_SCAN_DIR': '${tmp.path}/lib',
          'FILE_SIZE_PATH_PREFIX': tmp.path,
          'FILE_SIZE_BASELINE_FILE': baselinePath,
          'FILE_SIZE_THRESHOLD': '800',
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('file_size_ceiling_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      scriptPath = File('scripts/check_file_size_ceiling.sh').absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('script exists and is executable', () {
      expect(File(scriptPath).existsSync(), isTrue);
    });

    test('UPDATE_BASELINE freezes only files over the threshold', () {
      writeLines('big.dart', 900);
      writeLines('ok.dart', 100);

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, hasLength(1));
      expect(baseline.single, contains('lib/big.dart'));
      expect(baseline.single, contains('900'));
    });

    test('passes (OK) when nothing changed', () {
      writeLines('big.dart', 900);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [file_size_ceiling]'));
    });

    test('warns but exits 0 when a baselined file grows past its ceiling', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big.dart', 950);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('WARN [file_size_ceiling]'));
      expect(res.stdout, contains('GREW'));
    });

    test('warns but exits 0 when a new file crosses the threshold', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big2.dart', 1000);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('WARN [file_size_ceiling]'));
      expect(res.stdout, contains('NEW file'));
    });

    test('passes (OK) when a file shrinks but stays over the threshold', () {
      writeLines('big.dart', 2000);
      run(update: true);

      writeLines('big.dart', 1500);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [file_size_ceiling]'));
    });

    test('does not warn when a baselined file drops below the threshold', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big.dart', 700);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [file_size_ceiling]'));
      expect(res.stdout, isNot(contains('WARN')));
    });
  });
}
