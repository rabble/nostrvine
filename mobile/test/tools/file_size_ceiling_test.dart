// ABOUTME: Tests the file-size advisory against a temporary Git base commit.
// ABOUTME: Verifies branch-local warnings and the advisory exit-zero contract.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('file_size_ceiling advisory', () {
    late Directory tmp;
    late String scriptPath;

    File libFile(String name) => File('${tmp.path}/lib/$name');

    void writeLines(String name, int count) {
      final file = libFile(name)..parent.createSync(recursive: true);
      file.writeAsStringSync('${List.filled(count, '// line').join('\n')}\n');
    }

    ProcessResult git(List<String> arguments) =>
        Process.runSync('git', arguments, workingDirectory: tmp.path);

    void commitBase() {
      expect(git(['add', '.']).exitCode, 0);
      final result = git([
        '-c',
        'user.name=File Size Test',
        '-c',
        'user.email=file-size-test@example.invalid',
        'commit',
        '-m',
        'base',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }

    ProcessResult run({String baseRef = 'HEAD', bool allowNoBase = false}) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'FILE_SIZE_REPO_ROOT': tmp.path,
          'FILE_SIZE_SCAN_DIR': '${tmp.path}/lib',
          'FILE_SIZE_PATH_PREFIX': tmp.path,
          'FILE_SIZE_BASE_REF': baseRef,
          'FILE_SIZE_BASE_REPO_PATH': 'lib',
          'FILE_SIZE_BASE_PATH_PREFIX': '',
          'FILE_SIZE_THRESHOLD': '800',
          if (allowNoBase) 'FILE_SIZE_CEILING_ALLOW_NO_BASE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('file_size_ceiling_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      scriptPath = File('scripts/check_file_size_ceiling.sh').absolute.path;
      expect(git(['init', '-q']).exitCode, 0);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('passes when the oversized inventory matches the base commit', () {
      writeLines('big.dart', 900);
      writeLines('small.dart', 100);
      commitBase();

      final result = run();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('OK [file_size_ceiling]'));
      expect(result.stdout, contains('1 file(s) over 800 lines'));
    });

    test('warns but exits zero when a base file grows', () {
      writeLines('big.dart', 900);
      commitBase();
      writeLines('big.dart', 950);

      final result = run();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('WARN [file_size_ceiling]'));
      expect(result.stdout, contains('GREW'));
      expect(result.stdout, contains('lib/big.dart\t900 -> 950'));
    });

    test('warns but exits zero when a new file crosses the threshold', () {
      writeLines('existing.dart', 900);
      commitBase();
      writeLines('new.dart', 1000);

      final result = run();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('NEW file'));
      expect(result.stdout, contains('lib/new.dart\t1000'));
    });

    test('does not warn when a file shrinks or is deleted', () {
      writeLines('shrunk.dart', 1000);
      writeLines('deleted.dart', 900);
      commitBase();
      writeLines('shrunk.dart', 850);
      libFile('deleted.dart').deleteSync();

      final result = run();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('OK [file_size_ceiling]'));
      expect(result.stdout, isNot(contains('WARN')));
    });

    test('excludes generated files from current and base inventories', () {
      writeLines('model.g.dart', 900);
      writeLines('l10n/generated/messages.dart', 900);
      commitBase();
      writeLines('model.g.dart', 1000);
      writeLines('l10n/generated/messages.dart', 1000);

      final result = run();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('0 file(s) over 800 lines'));
      expect(result.stdout, isNot(contains('WARN')));
    });

    test('warns but exits zero when the base ref is unavailable', () {
      writeLines('big.dart', 900);
      commitBase();

      final result = run(baseRef: 'missing-ref');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('WARN [file_size_ceiling]'));
      expect(result.stdout, contains('missing-ref unavailable'));
    });

    test('allows an acknowledged local skip when the base is unavailable', () {
      writeLines('big.dart', 900);
      commitBase();

      final result = run(baseRef: 'missing-ref', allowNoBase: true);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('NOTE [file_size_ceiling]'));
      expect(result.stdout, isNot(contains('WARN')));
    });
  });
}
