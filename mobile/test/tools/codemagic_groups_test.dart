// ABOUTME: Tests for the Codemagic group guard (scripts/check_codemagic_groups.sh)
// ABOUTME: Pins the two-way invariant and the #6999 regression it exists to catch

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_codemagic_groups.sh` against synthetic codemagic.yaml
/// fixtures via CODEMAGIC_YAML, so the invariant is verified without depending
/// on the real file's current contents.
///
/// The guard exists because Codemagic validates the entire config *before*
/// provisioning a machine: a `groups:` entry naming a group that does not exist
/// fails every workflow in the file, and no in-script guard can catch it
/// because no script runs. #6999 shipped exactly that and took the pipeline
/// down for ~21 hours (#7203).
void main() {
  group('check_codemagic_groups', () {
    late Directory tmp;
    late String scriptPath;

    /// Minimal codemagic.yaml: a header checklist naming [documented] groups,
    /// and one workflow referencing [referenced].
    String yaml({
      required List<String> documented,
      required List<String> referenced,
    }) {
      final header = documented
          .map((g) => '# n - Create environment variable group "$g" with:')
          .join('\n');
      final refs = referenced.map((g) => '        - $g').join('\n');
      return '''
# Steps to setup:
$header

definitions:
  scripts:
    - &noop
      name: noop
      script: echo hi

workflows:
  demo:
    name: Demo
    environment:
      groups:
$refs
      vars:
        FOO: bar
    scripts:
      - *noop
''';
    }

    ProcessResult run(String contents) {
      final f = File('${tmp.path}/codemagic.yaml')..writeAsStringSync(contents);
      return Process.runSync(
        'bash',
        [scriptPath],
        // No Codemagic credentials: the advisory API layer must stay inert, so
        // these assertions cover the offline path CI and forks actually run.
        environment: {'CODEMAGIC_YAML': f.path},
        includeParentEnvironment: false,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('codemagic_groups_test');
      scriptPath = File('scripts/check_codemagic_groups.sh').absolute.path;
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('script exists', () {
      expect(File(scriptPath).existsSync(), isTrue);
    });

    test('passes when every referenced group is documented', () {
      final r = run(
        yaml(
          documented: ['zendesk_credentials', 'proofmode_credentials'],
          referenced: ['zendesk_credentials', 'proofmode_credentials'],
        ),
      );
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('fails when a referenced group is undocumented', () {
      final r = run(
        yaml(
          documented: ['zendesk_credentials'],
          referenced: ['zendesk_credentials', 'supporters_credentials'],
        ),
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('supporters_credentials'));
    });

    test('names every undocumented group, not just the first', () {
      final r = run(
        yaml(
          documented: ['zendesk_credentials'],
          referenced: [
            'zendesk_credentials',
            'supporters_credentials',
            'maestro_e2e_credentials',
          ],
        ),
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('supporters_credentials'));
      expect(r.stderr, contains('maestro_e2e_credentials'));
    });

    test('fails when the checklist documents a group nothing references', () {
      // The reverse invariant: without it the checklist ossifies with setup
      // steps for groups no workflow uses, and stops being trustworthy.
      final r = run(
        yaml(
          documented: ['zendesk_credentials', 'retired_credentials'],
          referenced: ['zendesk_credentials'],
        ),
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('retired_credentials'));
    });

    test('only the header counts as documentation', () {
      // A group named further down the file — in a comment beside its own
      // `groups:` entry, say — must not satisfy the checklist requirement.
      final base = yaml(
        documented: ['zendesk_credentials'],
        referenced: ['zendesk_credentials', 'supporters_credentials'],
      );
      final r = run(
        base.replaceFirst(
          '        - supporters_credentials',
          '        # "supporters_credentials" is set up in Codemagic\n'
              '        - supporters_credentials',
        ),
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('supporters_credentials'));
    });

    test('reports a helpful path when codemagic.yaml is missing', () {
      final r = Process.runSync(
        'bash',
        [scriptPath],
        environment: {'CODEMAGIC_YAML': '${tmp.path}/absent.yaml'},
        includeParentEnvironment: false,
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('cannot find codemagic.yaml'));
    });

    test('the real codemagic.yaml satisfies the invariant', () {
      // Guards the checked-in file itself, so a PR adding a `groups:` entry
      // without its setup step fails here rather than in production.
      final r = Process.runSync('bash', [scriptPath]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });
}
