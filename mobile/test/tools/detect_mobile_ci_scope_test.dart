// ABOUTME: Tests Mobile CI scope detection across PR and merge-queue events.
// ABOUTME: Pins app/native classification and every fall-open API boundary.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('detect_mobile_ci_scope.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late String outputPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('mobile_ci_scope_');
      scriptPath = File(
        p.join(
          Directory.current.path,
          'scripts',
          'ci',
          'detect_mobile_ci_scope.sh',
        ),
      ).absolute.path;
      outputPath = p.join(sandbox.path, 'github-output');

      final fakeGh = File(p.join(sandbox.path, 'bin', 'gh'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          r'''
set -euo pipefail

emit_files() {
  if [ -n "${FAKE_CHANGED_FILES:-}" ]; then
    printf '%s\n' "$FAKE_CHANGED_FILES"
  fi
}

case "$*" in
  *"/files"*) emit_files ;;
  *".changed_files"*) printf '%s\n' "${FAKE_CHANGED_TOTAL:-0}" ;;
  *"/compare/"*) emit_files ;;
  *) echo "Unexpected gh invocation: $*" >&2; exit 2 ;;
esac
''',
        );
      Process.runSync('chmod', ['+x', fakeGh.path]);
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ({ProcessResult result, Map<String, String> outputs}) runDetector({
      required String event,
      List<String> changedFiles = const [],
      int changedTotal = 0,
    }) {
      final result = Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'PATH':
              '${p.join(sandbox.path, 'bin')}:${Platform.environment['PATH']}',
          'GITHUB_EVENT_NAME': event,
          'GITHUB_REPOSITORY': 'divinevideo/divine-mobile',
          'GITHUB_OUTPUT': outputPath,
          'PR_NUMBER': '7058',
          'QUEUE_BASE_SHA': 'base-sha',
          'QUEUE_HEAD_SHA': 'head-sha',
          'FAKE_CHANGED_FILES': changedFiles.join('\n'),
          'FAKE_CHANGED_TOTAL': '$changedTotal',
        },
      );

      final outputs = <String, String>{};
      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        for (final line in outputFile.readAsLinesSync()) {
          final separator = line.indexOf('=');
          if (separator > 0) {
            outputs[line.substring(0, separator)] = line.substring(
              separator + 1,
            );
          }
        }
      }
      return (result: result, outputs: outputs);
    }

    void expectScope(
      ({ProcessResult result, Map<String, String> outputs}) run, {
      required bool app,
      required bool native,
    }) {
      expect(run.result.exitCode, 0, reason: run.result.stderr.toString());
      expect(run.outputs, {'app': '$app', 'native': '$native'});
    }

    for (final event in ['pull_request', 'merge_group']) {
      group(event, () {
        test('runs app CI for app code', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['mobile/lib/main.dart'],
              changedTotal: 1,
            ),
            app: true,
            native: false,
          );
        });

        test('skips app CI for docs-only changes', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['docs/merge-queue.md'],
              changedTotal: 1,
            ),
            app: false,
            native: false,
          );
        });

        test('runs app and native checks for native configuration', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['mobile/ios/Runner/Info.plist'],
              changedTotal: 1,
            ),
            app: true,
            native: true,
          );
        });
      });
    }

    test('merge group falls open when compare output is empty', () {
      final run = runDetector(event: 'merge_group');

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('returned 0 files'));
    });

    test('merge group falls open at the 300-file compare cap', () {
      final run = runDetector(
        event: 'merge_group',
        changedFiles: [for (var i = 0; i < 300; i++) 'docs/file_$i.md'],
      );

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('returned 300 files'));
    });

    test('pull request falls open above the 3000-file API cap', () {
      final run = runDetector(
        event: 'pull_request',
        changedFiles: ['docs/only.md'],
        changedTotal: 3001,
      );

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('touches 3001 files'));
    });

    test('push falls open to preserve the full main-branch matrix', () {
      expectScope(runDetector(event: 'push'), app: true, native: true);
    });
  });
}
