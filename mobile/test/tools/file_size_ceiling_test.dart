// ABOUTME: Tests for the file-size ceiling ratchet (scripts/check_file_size_ceiling.sh)
// ABOUTME: Verifies bootstrap, pass, growth-fail, new-file-fail, stale-fail, and within-threshold shrink

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_file_size_ceiling.sh` against an isolated temp tree so
/// the numeric per-file ceiling logic (epic #4339, PR-1) is verified without
/// touching the real baseline. The bash script is the source of truth; this
/// test pins its exit-code contract.
void main() {
  group('file_size_ceiling ratchet', () {
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

    ProcessResult run({
      bool update = false,
      bool allowNoBase = true,
      String baseRef = 'refs/heads/file-size-ceiling-test-no-base-ref',
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'FILE_SIZE_SCAN_DIR': '${tmp.path}/lib',
          'FILE_SIZE_PATH_PREFIX': tmp.path,
          'FILE_SIZE_BASELINE_FILE': baselinePath,
          'FILE_SIZE_BASELINE_BASE_REF': baseRef,
          'FILE_SIZE_THRESHOLD': '800',
          'FILE_SIZE_CEILING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
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

    test('passes when nothing changed', () {
      writeLines('big.dart', 900);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [file_size_ceiling]'));
    });

    test('fails when a baselined file grows past its ceiling', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big.dart', 950);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW'));
    });

    test('fails when a new file crosses the threshold', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big2.dart', 1000);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW file'));
    });

    test('fails (stale) when a baselined file drops below the threshold', () {
      writeLines('big.dart', 900);
      run(update: true);

      writeLines('big.dart', 700);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer over'));
    });

    test('passes when a file shrinks but stays over the threshold', () {
      writeLines('big.dart', 2000);
      run(update: true);

      writeLines('big.dart', 1500);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [file_size_ceiling]'));
    });

    test('fails when the branch baseline adds a file vs base ref', () {
      writeLines('big.dart', 900);
      run(update: true);

      final res = run(allowNoBase: false, baseRef: 'HEAD');
      expect(res.exitCode, 1);
      expect(res.stdout, contains('ADDED a file or RAISED a ceiling'));
      expect(res.stdout, contains('+added lib/big.dart'));
    });
  });
}
