// ABOUTME: Tests for the raw-Icons ceiling ratchet (scripts/check_raw_icons_ceiling.sh)
// ABOUTME: Verifies bootstrap, comment-exclusion, pass, growth/new/stale-fail, shrink-pass, anti-bypass

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_raw_icons_ceiling.sh` against an isolated temp tree so
/// the per-file raw-`Icons.*` ceiling logic (#4803, epic #4339) is verified
/// without touching the real baseline. The bash script is the source of truth;
/// this test pins its exit-code contract.
void main() {
  group('raw_icons_ceiling ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    File libFile(String name) => File('${tmp.path}/lib/$name');

    // Writes [n] code lines, each containing exactly one raw `Icons.*` match.
    void writeIcons(String name, int n) {
      final body = List.filled(
        n,
        'final w = const Icon(Icons.add);',
      ).join('\n');
      libFile(name).writeAsStringSync('$body\n');
    }

    void writeRaw(String name, String contents) {
      libFile(name).writeAsStringSync(contents);
    }

    ProcessResult run({
      bool update = false,
      bool allowNoBase = true,
      String baseRef = 'refs/heads/raw-icons-ceiling-test-no-base-ref',
      String? baseRepoPath,
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'RAW_ICONS_SCAN_DIR': '${tmp.path}/lib',
          'RAW_ICONS_PATH_PREFIX': tmp.path,
          'RAW_ICONS_BASELINE_FILE': baselinePath,
          'RAW_ICONS_BASELINE_BASE_REF': baseRef,
          'RAW_ICONS_CEILING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          'RAW_ICONS_BASELINE_REPO_PATH': ?baseRepoPath,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('raw_icons_ceiling_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      scriptPath = File('scripts/check_raw_icons_ceiling.sh').absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('script exists', () {
      expect(File(scriptPath).existsSync(), isTrue);
    });

    test('UPDATE_BASELINE freezes only files using raw Icons.*', () {
      writeIcons('uses.dart', 3);
      writeIcons('clean.dart', 0); // 0 icons -> empty file, excluded

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, hasLength(1));
      expect(baseline.single, contains('lib/uses.dart'));
      expect(baseline.single, contains('3'));
    });

    test('does not count raw Icons.* inside full-line doc comments', () {
      writeRaw('doc.dart', '/// Example: const Icon(Icons.favorite)\n');

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, isEmpty);
    });

    test('passes when nothing changed', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [raw_icons_ceiling]'));
    });

    test('fails when a baselined file gains icons past its ceiling', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('uses.dart', 5);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GAINED'));
    });

    test('fails when a new file introduces raw Icons.*', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('newbie.dart', 1);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW file'));
    });

    test('fails (stale) when a baselined file drops all raw Icons.*', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('uses.dart', 0);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer use raw Icons'));
    });

    test('passes when a file drops some icons but stays above zero', () {
      writeIcons('uses.dart', 5);
      run(update: true);

      writeIcons('uses.dart', 2);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [raw_icons_ceiling]'));
    });

    test('fails when the branch baseline adds a file vs base ref', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      // The real raw_icons baseline isn't committed yet, so diff the temp
      // baseline against an already-committed baseline-format file (file_sizes)
      // to exercise the anti-bypass ADDED path. 'lib/uses.dart' is absent from
      // that base, so it must be flagged as added.
      final res = run(
        allowNoBase: false,
        baseRef: 'HEAD',
        baseRepoPath: 'mobile/scripts/baseline/file_sizes.txt',
      );
      expect(res.exitCode, 1);
      expect(res.stdout, contains('ADDED a file or RAISED a ceiling'));
      expect(res.stdout, contains('+added lib/uses.dart'));
    });
  });
}
