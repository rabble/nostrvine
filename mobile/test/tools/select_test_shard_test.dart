// ABOUTME: Tests the CI test-sharding selector used by Mobile CI's Tests job.
// ABOUTME: Pins that the shards are an exact partition of test/**/*_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `scripts/ci/select_test_shard.sh` against an isolated temp tree.
///
/// The whole safety argument for sharding is that the union of the shards is
/// exactly the set of test files, with no file dropped and none run twice. A
/// dropped file would silently stop being tested while CI stayed green, so
/// that property is pinned here rather than trusted.
void main() {
  group('select_test_shard.sh', () {
    late Directory sandbox;
    late String scriptPath;

    /// Builds `<sandbox>/scripts/ci/select_test_shard.sh` plus a `test/` tree,
    /// so the script's own PROJECT_ROOT resolution points at the sandbox.
    void createSandbox({
      required List<String> testFiles,
      List<String> otherFiles = const [],
    }) {
      final realScript = File(
        p.join(Directory.current.path, 'scripts', 'ci', 'select_test_shard.sh'),
      );
      expect(
        realScript.existsSync(),
        isTrue,
        reason: 'scripts/ci/select_test_shard.sh must exist',
      );

      scriptPath = p.join(
        sandbox.path,
        'scripts',
        'ci',
        'select_test_shard.sh',
      );
      File(scriptPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(realScript.readAsStringSync());
      Process.runSync('chmod', ['+x', scriptPath]);

      for (final relative in [...testFiles, ...otherFiles]) {
        File(p.join(sandbox.path, relative))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('// $relative\n');
      }
    }

    ProcessResult runShard(int index, int total, {bool force = true}) {
      return Process.runSync('bash', [
        scriptPath,
        '--total',
        '$total',
        '--index',
        '$index',
        if (force) '--force',
      ]);
    }

    List<String> survivingTestFiles() {
      final root = Directory(p.join(sandbox.path, 'test'));
      return root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: sandbox.path))
          .where((f) => f.endsWith('_test.dart'))
          .toList()
        ..sort();
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('select_test_shard_');
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('shards partition every test file exactly once', () {
      final allTests = [
        for (var i = 0; i < 17; i++)
          p.join('test', 'group_${i % 4}', 'a${i}_test.dart'),
      ]..sort();
      const total = 4;

      final seen = <String>[];
      for (var index = 0; index < total; index++) {
        // Each shard needs its own pristine copy — the script deletes files.
        sandbox.deleteSync(recursive: true);
        sandbox = Directory.systemTemp.createTempSync('select_test_shard_');
        createSandbox(testFiles: allTests);

        final result = runShard(index, total);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        seen.addAll(survivingTestFiles());
      }

      expect(seen.toSet(), equals(allTests.toSet()));
      expect(
        seen.length,
        equals(allTests.length),
        reason: 'a file was assigned to more than one shard',
      );
    });

    test(
      'leaves non-test sources in place so surviving tests still import them',
      () {
        createSandbox(
          testFiles: [
            p.join('test', 'a_test.dart'),
            p.join('test', 'b_test.dart'),
          ],
          otherFiles: [
            p.join('test', 'helpers', 'test_helpers.dart'),
            p.join('test', 'flutter_test_config.dart'),
            p.join('test', 'mocks', 'mock_thing.dart'),
          ],
        );

        expect(runShard(0, 2).exitCode, 0);

        for (final kept in [
          p.join('test', 'helpers', 'test_helpers.dart'),
          p.join('test', 'flutter_test_config.dart'),
          p.join('test', 'mocks', 'mock_thing.dart'),
        ]) {
          expect(
            File(p.join(sandbox.path, kept)).existsSync(),
            isTrue,
            reason: '$kept is not a test entry point and must survive sharding',
          );
        }
      },
    );

    test('--dry-run changes nothing', () {
      final allTests = [
        p.join('test', 'a_test.dart'),
        p.join('test', 'b_test.dart'),
      ];
      createSandbox(testFiles: allTests);

      final result = Process.runSync('bash', [
        scriptPath,
        '--total',
        '2',
        '--index',
        '0',
        '--dry-run',
      ]);

      expect(result.exitCode, 0);
      expect(survivingTestFiles(), equals(allTests..sort()));
    });

    test('refuses an index outside the shard range', () {
      createSandbox(testFiles: [p.join('test', 'a_test.dart')]);

      final result = runShard(2, 2);

      expect(result.exitCode, 2);
      expect(survivingTestFiles(), hasLength(1));
    });

    test(
      'fails rather than reporting a vacuous pass when a shard is empty',
      () {
        // One file, four shards: shards 1..3 select nothing. A silent success
        // there would mean a green CI leg that ran no tests at all.
        createSandbox(testFiles: [p.join('test', 'only_test.dart')]);

        final result = runShard(3, 4);

        expect(result.exitCode, 1);
        expect(result.stderr, contains('0 test files'));
      },
    );

    test('refuses to delete outside CI without --force', () {
      createSandbox(testFiles: [p.join('test', 'a_test.dart')]);

      final result = Process.runSync(
        'bash',
        [scriptPath, '--total', '2', '--index', '0'],
        environment: {'CI': ''},
      );

      expect(result.exitCode, 2);
      expect(survivingTestFiles(), hasLength(1));
    });
  });
}
