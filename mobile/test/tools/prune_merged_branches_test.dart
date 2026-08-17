// ABOUTME: Tests for scripts/prune-merged-branches.sh.
// ABOUTME: Pins conservative report-only branch classification.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('prune-merged-branches.sh', () {
    late Directory sandbox;
    late Directory repo;
    late String scriptPath;
    late File fakeGh;
    late File ghArgs;

    void git(
      List<String> args, {
      String? workingDirectory,
      Map<String, String>? environment,
    }) {
      final result = Process.runSync(
        'git',
        args,
        workingDirectory: workingDirectory ?? repo.path,
        environment: environment,
      );
      expect(
        result.exitCode,
        0,
        reason:
            'git ${args.join(' ')}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    }

    String branchTip(String branch) {
      final result = Process.runSync('git', [
        'rev-parse',
        branch,
      ], workingDirectory: repo.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return result.stdout.toString().trim();
    }

    void write(String relativePath, String contents, {String? root}) {
      final file = File(p.join(root ?? repo.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    void commit(String message) {
      git(['add', '.']);
      git(['commit', '-m', message]);
    }

    void makeBranch(String branch, String contents) {
      git(['checkout', '-B', branch, 'main']);
      write('$branch.txt', contents);
      commit('add $branch');
      git(['checkout', 'main']);
    }

    ProcessResult runScript({
      required List<String> mergedHeadRefs,
      required List<String> githubCommitShas,
      List<String> args = const [],
    }) {
      return Process.runSync(
        'bash',
        [scriptPath, ...args],
        workingDirectory: repo.path,
        environment: {
          'PATH':
              '${p.join(sandbox.path, 'bin')}:${Platform.environment['PATH']}',
          'GH': fakeGh.path,
          'REPO': 'divinevideo/divine-mobile',
          'MERGED_PR_LIMIT': '100000',
          'FAKE_MERGED_HEAD_REFS': mergedHeadRefs.join('\n'),
          'FAKE_GITHUB_COMMIT_SHAS': githubCommitShas.join('\n'),
          'FAKE_GH_ARGS': ghArgs.path,
        },
      );
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('prune_merged_branches_');
      scriptPath = File(
        p.join(
          Directory.current.parent.path,
          'scripts',
          'prune-merged-branches.sh',
        ),
      ).absolute.path;
      repo = Directory(p.join(sandbox.path, 'repo'))..createSync();
      final remote = Directory(p.join(sandbox.path, 'remote.git'));
      ghArgs = File(p.join(sandbox.path, 'gh-args.txt'));

      fakeGh = File(p.join(sandbox.path, 'bin', 'gh'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          r'''
set -euo pipefail

printf '%s\n' "$*" >> "${FAKE_GH_ARGS:?}"

if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  if [ -n "${FAKE_MERGED_HEAD_REFS:-}" ]; then
    printf '%s\n' "$FAKE_MERGED_HEAD_REFS"
  fi
  exit 0
fi

if [ "$1" = "api" ]; then
  sha="${*: -1}"
  sha="${sha##*/}"
  if printf '%s\n' "${FAKE_GITHUB_COMMIT_SHAS:-}" | grep -qxF -- "$sha"; then
    printf '{}\n'
    exit 0
  fi
  exit 1
fi

echo "Unexpected gh invocation: $*" >&2
exit 2
''',
        );
      Process.runSync('chmod', ['+x', fakeGh.path]);

      git(['init', '--bare', remote.path], workingDirectory: sandbox.path);
      git(['init']);
      git(['config', 'user.email', 'test@example.com']);
      git(['config', 'user.name', 'Test User']);
      write('.gitignore', '.env\nbuild/\n');
      write('README.md', 'fixture\n');
      commit('initial');
      git(['branch', '-M', 'main']);
      git(['remote', 'add', 'origin', remote.path]);
      git(['push', '-u', 'origin', 'main']);
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('reports merged branch only when the local tip exists on GitHub', () {
      makeBranch('merged-branch', 'merged');
      final mergedTip = branchTip('merged-branch');
      makeBranch('reused-branch-name', 'local only');

      final result = runScript(
        mergedHeadRefs: ['merged-branch', 'reused-branch-name'],
        githubCommitShas: [mergedTip],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('MERGED-PR      merged-branch'));
      expect(result.stdout, contains('KEEP-LOCAL     reused-branch-name'));
    });

    test('keeps merged branches whose worktree contains ignored files', () {
      makeBranch('dirty-worktree', 'merged');
      final tip = branchTip('dirty-worktree');
      final worktree = Directory(p.join(sandbox.path, 'dirty-worktree'));
      git(['worktree', 'add', worktree.path, 'dirty-worktree']);
      write('.env', 'local secret\n', root: worktree.path);

      final result = runScript(
        mergedHeadRefs: ['dirty-worktree'],
        githubCommitShas: [tip],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('KEEP-DIRTY'));
      expect(result.stdout, contains('dirty-worktree'));
      expect(File(p.join(worktree.path, '.env')).existsSync(), isTrue);
    });

    test('asks GitHub for a broad filtered merged PR set', () {
      makeBranch('merged-branch', 'merged');

      final result = runScript(
        mergedHeadRefs: ['merged-branch'],
        githubCommitShas: [branchTip('merged-branch')],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final args = ghArgs.readAsStringSync();
      expect(args, contains('--limit 100000'));
      expect(
        args,
        contains('--json headRefName,isCrossRepository,baseRefName'),
      );
      expect(args, contains('isCrossRepository == false'));
      expect(args, contains('baseRefName == "main"'));
    });

    test('--help prints usage and exits without fetching', () {
      final result = runScript(
        args: ['--help'],
        mergedHeadRefs: const [],
        githubCommitShas: const [],
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('bash scripts/prune-merged-branches.sh'));
      expect(result.stdout, isNot(contains('Fetching origin')));
    });

    test('--execute is rejected while deletion lives outside this PR', () {
      final result = runScript(
        args: ['--execute'],
        mergedHeadRefs: const [],
        githubCommitShas: const [],
      );

      expect(result.exitCode, 2);
      expect(result.stderr, contains('unknown argument: --execute'));
    });
  });
}
