// ABOUTME: Shared contract tests for both Future.delayed ratchets.
// ABOUTME: Runs each guard against isolated code fixtures and baselines.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void defineFutureDelayedCeilingTests({
  required String scriptName,
  required String baselineName,
  required String sourceDirectoryName,
  required String allowNoBaseVariable,
}) {
  group(scriptName, () {
    late Directory sandbox;
    late Directory sourceDirectory;
    late File baseline;
    late String repoRoot;

    File sourceFile(String name) => File('${sourceDirectory.path}/$name');

    void writeBaseline(String body) => baseline.writeAsStringSync(body);

    ProcessResult runRatchet({bool update = false}) => Process.runSync(
      'bash',
      ['scripts/$scriptName'],
      workingDirectory: sandbox.path,
      environment: {
        allowNoBaseVariable: '1',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );

    String output(ProcessResult result) => '${result.stdout}${result.stderr}';

    setUp(() {
      repoRoot = Directory.current.path;
      sandbox = Directory.systemTemp.createTempSync('fd_ceiling_');
      sourceDirectory = Directory('${sandbox.path}/$sourceDirectoryName')
        ..createSync(recursive: true);
      Directory('${sandbox.path}/scripts/baseline').createSync(recursive: true);
      Directory('${sandbox.path}/scripts/lib').createSync(recursive: true);

      File(
        '$repoRoot/scripts/$scriptName',
      ).copySync('${sandbox.path}/scripts/$scriptName');
      for (final name in ['dart_code_only.awk', 'numeric_ratchet.sh']) {
        File(
          '$repoRoot/scripts/lib/$name',
        ).copySync('${sandbox.path}/scripts/lib/$name');
      }
      baseline = File('${sandbox.path}/scripts/baseline/$baselineName');
      writeBaseline('# frozen baseline\n');
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    test('counts a real call', () {
      sourceFile('real.dart').writeAsStringSync('''
Future<void> wait() async {
  await Future.delayed(const Duration(milliseconds: 100));
}
''');

      final result = runRatchet();

      expect(result.exitCode, 1);
      expect(output(result), contains('$sourceDirectoryName/real.dart\t1'));
    });

    test('counts multiple calls on the same line', () {
      sourceFile('two.dart').writeAsStringSync('''
final waits = [Future.delayed(Duration.zero), Future.delayed(Duration.zero)];
''');

      final result = runRatchet();

      expect(result.exitCode, 1);
      expect(output(result), contains('$sourceDirectoryName/two.dart\t2'));
    });

    test('does not count line comments', () {
      sourceFile('line_comment.dart').writeAsStringSync('''
// Use an owned Timer instead of Future.delayed here.
Future<void> wait() async {}
''');

      expect(
        output(runRatchet()),
        isNot(contains('$sourceDirectoryName/line_comment.dart')),
      );
    });

    test('does not count dartdoc references', () {
      sourceFile('dartdoc.dart').writeAsStringSync('''
/// React to completion instead of guessing with [Future.delayed].
int controller = 0;
''');

      expect(
        output(runRatchet()),
        isNot(contains('$sourceDirectoryName/dartdoc.dart')),
      );
    });

    test('does not count block comments', () {
      sourceFile('block_comment.dart').writeAsStringSync('''
/* legacy note about Future.delayed
   spanning several lines */
int value = 0;
''');

      expect(
        output(runRatchet()),
        isNot(contains('$sourceDirectoryName/block_comment.dart')),
      );
    });

    test('does not count string literals', () {
      sourceFile('string_literal.dart').writeAsStringSync('''
final message = 'replaced Future.delayed with an owned Timer';
''');

      expect(
        output(runRatchet()),
        isNot(contains('$sourceDirectoryName/string_literal.dart')),
      );
    });

    test('counts an early call in a large file without SIGPIPE loss', () {
      final filler = List.generate(
        4000,
        (i) => 'final int padding$i = $i;',
      ).join('\n');
      sourceFile('large.dart').writeAsStringSync(
        'Future<void> wait() async {\n'
        '  await Future.delayed(const Duration(milliseconds: 100));\n'
        '}\n'
        '$filler\n',
      );

      final result = runRatchet();

      expect(result.exitCode, 1);
      expect(output(result), contains('$sourceDirectoryName/large.dart\t1'));
    });

    test('counts code in a file that also documents a call', () {
      sourceFile('mixed.dart').writeAsStringSync('''
/// Historically this used [Future.delayed].
Future<void> wait() async {
  // Replace this Future.delayed with an owned Timer.
  await Future.delayed(const Duration(seconds: 1));
}
''');

      final result = runRatchet();

      expect(result.exitCode, 1);
      expect(output(result), contains('$sourceDirectoryName/mixed.dart\t1'));
    });

    test('fails when an existing file count grows', () {
      sourceFile('growth.dart').writeAsStringSync('''
Future<void> wait() async {
  await Future.delayed(Duration.zero);
  await Future.delayed(Duration.zero);
}
''');
      writeBaseline('$sourceDirectoryName/growth.dart\t1\n');

      final result = runRatchet();

      expect(result.exitCode, 1);
      expect(output(result), contains('GREW'));
      expect(output(result), contains('\t1 -> 2'));
    });

    test('a decrease can be regenerated and cannot grow back', () {
      sourceFile('decrease.dart').writeAsStringSync('''
Future<void> wait() async {
  await Future.delayed(Duration.zero);
}
''');
      writeBaseline('$sourceDirectoryName/decrease.dart\t2\n');

      final decreased = runRatchet();
      expect(decreased.exitCode, 0, reason: output(decreased));

      final update = runRatchet(update: true);
      expect(update.exitCode, 0, reason: output(update));
      expect(
        baseline.readAsStringSync(),
        contains('$sourceDirectoryName/decrease.dart\t1'),
      );

      sourceFile('decrease.dart').writeAsStringSync('''
Future<void> wait() async {
  await Future.delayed(Duration.zero);
  await Future.delayed(Duration.zero);
}
''');
      final regrown = runRatchet();
      expect(regrown.exitCode, 1);
      expect(output(regrown), contains('GREW'));
    });
  });
}
