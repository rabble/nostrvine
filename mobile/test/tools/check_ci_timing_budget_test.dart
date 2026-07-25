// ABOUTME: Tests the CI wall-clock budget guard used by the mobile-ci gate.
// ABOUTME: Pins warn/fail thresholds, prefix matching, and fail-closed cases.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `scripts/ci/check_ci_timing_budget.py` against synthetic job
/// payloads.
///
/// The guard exists to stop measured CI wins eroding, so the properties that
/// matter are that it actually fails when a job blows its budget, and that it
/// never reports success when it could not really check (bad budget file, no
/// job data, a budgeted job missing from the run).
void main() {
  group('check_ci_timing_budget.py', () {
    late Directory sandbox;
    late String scriptPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('ci_timing_budget_');
      scriptPath = p.join(
        Directory.current.path,
        'scripts',
        'ci',
        'check_ci_timing_budget.py',
      );
      expect(
        File(scriptPath).existsSync(),
        isTrue,
        reason: 'scripts/ci/check_ci_timing_budget.py must exist',
      );
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    String writeJson(String name, Object value) {
      final file = File(p.join(sandbox.path, name))
        ..writeAsStringSync(jsonEncode(value));
      return file.path;
    }

    /// A job that started at 00:00:00Z and ran for [seconds].
    Map<String, Object?> job(String name, int seconds, {String? conclusion}) {
      final minutes = seconds ~/ 60;
      final remainder = seconds % 60;
      return {
        'name': name,
        'conclusion': conclusion ?? 'success',
        'started_at': '2026-07-25T00:00:00Z',
        'completed_at':
            '2026-07-25T00:${minutes.toString().padLeft(2, '0')}:'
            '${remainder.toString().padLeft(2, '0')}Z',
      };
    }

    ProcessResult run({
      required Object budgets,
      required List<Map<String, Object?>> jobs,
    }) {
      return Process.runSync('python3', [
        scriptPath,
        '--budgets',
        writeJson('budgets.json', budgets),
        '--jobs-json',
        writeJson('jobs.json', {'jobs': jobs}),
      ]);
    }

    const oneBudget = {
      'jobs': {
        'Tests': {'warn': 100, 'fail': 200},
      },
    };

    test('passes when a budgeted job is inside its warn threshold', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 90)]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, isNot(contains('::warning')));
      expect(result.stdout, isNot(contains('::error')));
    });

    test('warns but still passes between warn and fail', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 150)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('::warning'));
      expect(result.stdout, contains('150s'));
    });

    test('fails once a job is over its fail threshold', () {
      final result = run(budgets: oneBudget, jobs: [job('Tests', 250)]);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('::error'));
      expect(result.stdout, contains('250s'));
    });

    test('one budget key covers every leg of a matrix job', () {
      // 'Tests' must match 'Tests (shard N/4)' so sharding does not silently
      // drop the whole job out of the budget.
      final result = run(
        budgets: oneBudget,
        jobs: [job('Tests (shard 0/4)', 90), job('Tests (shard 1/4)', 250)],
      );

      expect(result.exitCode, 1);
      expect(result.stdout, contains('Tests (shard 1/4)'));
    });

    test('does not let a similarly named job absorb the budget', () {
      // 'TestsExtra' is a different job, not a leg of 'Tests'.
      final result = run(budgets: oneBudget, jobs: [job('TestsExtra', 250)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('skipped or renamed'));
    });

    test('reports a budgeted job that did not run rather than passing it', () {
      final result = run(budgets: oneBudget, jobs: [job('Something Else', 10)]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('::notice'));
      expect(result.stdout, contains('Tests'));
    });

    test('ignores a failed run of a budgeted job', () {
      // A job that failed was cut short; its duration says nothing about speed.
      final result = run(
        budgets: oneBudget,
        jobs: [job('Tests', 250, conclusion: 'failure')],
      );

      expect(result.exitCode, 0);
      expect(result.stdout, isNot(contains('::error')));
    });

    test('exits 2 when the job payload is empty', () {
      final result = run(budgets: oneBudget, jobs: []);

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when a budget has warn above fail', () {
      final result = run(
        budgets: {
          'jobs': {
            'Tests': {'warn': 300, 'fail': 100},
          },
        },
        jobs: [job('Tests', 50)],
      );

      expect(result.exitCode, 2);
      expect(result.stdout, contains('cannot run'));
    });

    test('exits 2 when the budget file has no jobs', () {
      final result = run(
        budgets: {'jobs': <String, Object>{}},
        jobs: [job('Tests', 50)],
      );

      expect(result.exitCode, 2);
    });

    test(
      'the committed budget file is well formed and covers the gate jobs',
      () {
        final committed = File(
          p.join(
            Directory.current.parent.path,
            '.github',
            'ci-timing-budgets.json',
          ),
        );
        expect(committed.existsSync(), isTrue);

        final decoded =
            jsonDecode(committed.readAsStringSync()) as Map<String, dynamic>;
        final jobs = decoded['jobs'] as Map<String, dynamic>;

        // The jobs the mobile-ci gate depends on must all carry a budget,
        // otherwise a regression in one of them is invisible to the guard.
        for (final name in const [
          'Detect App CI Scope',
          'Tests',
          'Generated Files',
          'Analyze',
          'Format',
          'VGV Tag Gate',
        ]) {
          expect(jobs, contains(name), reason: '$name has no timing budget');
          final entry = jobs[name] as Map<String, dynamic>;
          expect(
            (entry['warn'] as num) < (entry['fail'] as num),
            isTrue,
            reason: '$name has warn >= fail',
          );
        }
      },
    );
  });
}
