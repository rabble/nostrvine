// ABOUTME: Tests for the production Future.delayed ceiling ratchet (#6934).
// ABOUTME: Pins that it counts real calls only, never comments or doc references.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `check_future_delayed_production_ceiling.sh` against an isolated temp
/// tree so its detector semantics are pinned without touching the real
/// baseline. The bash script is the source of truth; this test pins the
/// contract its header promises.
///
/// The contract that matters: the script strips comments and string literals
/// through `lib/dart_code_only.awk` before matching, like the seven sibling
/// ratchets. Before #6934 it grepped raw source, so two of its eleven baseline
/// entries were files that only *mention* `Future.delayed` — one of them a
/// dartdoc reference stating the file deliberately does not use it — which made
/// the ratchet's stated goal of reaching zero unreachable by construction.
void main() {
  group('check_future_delayed_production_ceiling.sh', () {
    late Directory sandbox;
    late Directory libDir;
    late String repoRoot;

    setUp(() {
      // test/tools/<file> -> mobile/
      repoRoot = Directory.current.path;
      sandbox = Directory.systemTemp.createTempSync('fd_ceiling_');
      libDir = Directory('${sandbox.path}/lib')..createSync(recursive: true);
      Directory('${sandbox.path}/scripts/baseline').createSync(recursive: true);
      // The script resolves MOBILE_DIR from its own location, so the sandbox
      // needs the script and the awk filter at the same relative paths.
      File(
        '$repoRoot/scripts/check_future_delayed_production_ceiling.sh',
      ).copySync(
        '${sandbox.path}/scripts/check_future_delayed_production_ceiling.sh',
      );
      Directory('${sandbox.path}/scripts/lib').createSync(recursive: true);
      for (final name in ['dart_code_only.awk', 'list_ratchet.sh']) {
        File(
          '$repoRoot/scripts/lib/$name',
        ).copySync('${sandbox.path}/scripts/lib/$name');
      }
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    /// Runs the ratchet with an empty baseline and returns its combined output.
    /// A file that the detector counts shows up as a new entry.
    ProcessResult runRatchet() {
      File(
        '${sandbox.path}/scripts/baseline/future_delayed_production.txt',
      ).writeAsStringSync('# frozen baseline\n');
      return Process.runSync(
        'bash',
        ['scripts/check_future_delayed_production_ceiling.sh'],
        workingDirectory: sandbox.path,
        environment: {'FUTURE_DELAYED_PROD_CEILING_ALLOW_NO_BASE': '1'},
      );
    }

    test('counts a real Future.delayed call', () {
      File('${libDir.path}/real.dart').writeAsStringSync('''
Future<void> wait() async {
  await Future.delayed(const Duration(milliseconds: 100));
}
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        contains('lib/real.dart'),
        reason: 'a genuine call site must be reported',
      );
    });

    test('does not count a line comment mentioning Future.delayed', () {
      File('${libDir.path}/line_comment.dart').writeAsStringSync('''
// Use an owned Timer instead of Future.delayed here.
Future<void> wait() async {}
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        isNot(contains('lib/line_comment.dart')),
        reason: 'a comment is not a call site',
      );
    });

    test('does not count a dartdoc reference to Future.delayed', () {
      // This is video_editor_timeline_clip_strip.dart's exact shape: a doc
      // comment stating the file deliberately does NOT use Future.delayed.
      File('${libDir.path}/dartdoc.dart').writeAsStringSync('''
/// Drives reorder timing so we can react to completion
/// instead of guessing with [Future.delayed].
int controller = 0;
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        isNot(contains('lib/dartdoc.dart')),
        reason: 'a dartdoc reference is not a call site',
      );
    });

    test('does not count a block comment mentioning Future.delayed', () {
      File('${libDir.path}/block_comment.dart').writeAsStringSync('''
/* legacy note about Future.delayed
   spanning several lines */
int value = 0;
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        isNot(contains('lib/block_comment.dart')),
        reason: 'a block comment is not a call site',
      );
    });

    test('does not count Future.delayed inside a string literal', () {
      File('${libDir.path}/string_literal.dart').writeAsStringSync('''
final message = 'replaced Future.delayed with an owned Timer';
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        isNot(contains('lib/string_literal.dart')),
        reason: 'a log/message string is not a call site',
      );
    });

    test('counts a real call near the top of a large file', () {
      // Regression for a SIGPIPE undercount. The first version of this
      // detector piped awk into `grep -qE`; `-q` exits on the first match,
      // awk then dies of SIGPIPE, and under `set -o pipefail` the pipeline
      // reports 141, so the `if` took the else branch. Only files large
      // enough that awk was still writing when grep exited were affected, so
      // every small fixture above passed while three real production files —
      // 965, 704 and 1106 lines — were silently dropped from the baseline.
      // Undercounting is the dangerous direction for a ceiling, so the match
      // here sits near the top with a lot of output behind it.
      final filler = List.generate(
        4000,
        (i) => 'final int padding$i = $i;',
      ).join('\n');
      File('${libDir.path}/large.dart').writeAsStringSync(
        'Future<void> wait() async {\n'
        '  await Future.delayed(const Duration(milliseconds: 100));\n'
        '}\n'
        '$filler\n',
      );

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        contains('lib/large.dart'),
        reason: 'an early match must not be lost to SIGPIPE on a large file',
      );
    });

    test('still counts a real call in a file that also documents one', () {
      // The dangerous direction for a ceiling is undercounting: a file must not
      // become invisible just because it carries an explanatory comment.
      File('${libDir.path}/mixed.dart').writeAsStringSync('''
/// Historically this used [Future.delayed]; see the note below.
Future<void> wait() async {
  // TODO(#6934): replace this Future.delayed with an owned Timer.
  await Future.delayed(const Duration(seconds: 1));
}
''');

      final result = runRatchet();

      expect(
        '${result.stdout}${result.stderr}',
        contains('lib/mixed.dart'),
        reason: 'comments must not mask a real call in the same file',
      );
    });
  });
}
