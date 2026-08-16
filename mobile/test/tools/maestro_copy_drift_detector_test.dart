// ABOUTME: Tests for the Maestro copy-drift guard.
// ABOUTME: Verifies drift, regen refusal, base erosion, comments, and rendered bindings.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_maestro_copy_drift.sh` against an isolated synthetic
/// mobile tree so the detector behavior from #6978 is pinned without touching
/// the real Maestro baseline.
void main() {
  group('maestro copy-drift guard', () {
    late Directory tmp;
    late Directory mobile;
    late File script;
    late File arb;
    late File manifest;

    File flow(String relative) => File('${mobile.path}/e2e/maestro/$relative');

    void writeArb(Map<String, String> values) {
      arb
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(values)}\n',
        );
    }

    void writeFlow(String relative, String body) {
      final file = flow(relative);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(body);
    }

    void writeManifest(String body) {
      manifest
        ..createSync(recursive: true)
        ..writeAsStringSync(body);
    }

    ProcessResult run({
      bool update = false,
      bool acceptRemovals = false,
      String? baseRef,
      bool allowNoBase = true,
    }) {
      final environment = <String, String>{};
      if (update) environment['UPDATE_BASELINE'] = '1';
      if (acceptRemovals) environment['ACCEPT_REMOVALS'] = '1';
      if (baseRef != null) environment['MAESTRO_COPY_DRIFT_BASE_REF'] = baseRef;
      if (allowNoBase) environment['MAESTRO_COPY_DRIFT_ALLOW_NO_BASE'] = '1';

      return Process.runSync(
        'bash',
        [script.path],
        workingDirectory: mobile.parent.path,
        environment: environment,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('maestro_copy_drift_test');
      mobile = Directory('${tmp.path}/mobile')..createSync(recursive: true);
      Directory('${mobile.path}/e2e/maestro').createSync(recursive: true);
      Directory('${mobile.path}/scripts').createSync(recursive: true);
      script = File(
        'scripts/check_maestro_copy_drift.sh',
      ).absolute.copySync('${mobile.path}/scripts/check_maestro_copy_drift.sh');
      arb = File('${mobile.path}/lib/l10n/app_en.arb');
      manifest = File(
        '${mobile.path}/scripts/baseline/maestro_copy_manifest.txt',
      );
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('passes and reports the binding denominator for a clean manifest', () {
      writeArb({'settingsTitle': 'Settings'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        res.stdout,
        contains('1 bindings verified (of 1 asserted literals extracted)'),
      );
    });

    test('fails when ARB copy changes under a bound flow', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stderr,
        contains('DRIFT: copy changed under the Maestro suite'),
      );
      expect(res.stderr, contains('Update the flow to the current copy first'));
    });

    test('regen refuses to erase a binding while key and flow still exist', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('regen refused'));
      expect(
        manifest.readAsStringSync(),
        'settingsTitle\te2e/maestro/asserts/menu.yaml\n',
      );
    });

    test('ACCEPT_REMOVALS makes an intentional vanished binding explicit', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run(update: true, acceptRemovals: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('WARNING: 1 binding(s) removed'));
      expect(
        manifest.readAsLinesSync().where(
          (line) => line.isNotEmpty && !line.startsWith('#'),
        ),
        isEmpty,
      );
    });

    test('commented-out copy does not satisfy a binding', () {
      writeArb({'settingsTitle': 'Settings'});
      writeFlow('asserts/menu.yaml', '# - assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stderr,
        contains('DRIFT: copy changed under the Maestro suite'),
      );
    });

    test('rendered ICU bindings are carried through regeneration', () {
      writeArb({'profileVideoThumbnailLabel': 'Video thumbnail {number}'});
      writeFlow('tests/searchTags.yaml', '- tapOn: Video thumbnail 1\n');
      writeManifest(
        'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
        '\trendered:Video thumbnail 1\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('1 hand-maintained'));
      expect(
        manifest.readAsStringSync(),
        contains(
          'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
          '\trendered:Video thumbnail 1',
        ),
      );
    });

    test('renamed ARB key does not excuse a vanished binding', () {
      writeArb({'authConnectSigner': 'Link a signer application'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: Connect with a signer app\n',
      );
      writeManifest(
        'authConnectSignerApp\te2e/maestro/asserts/menu.yaml'
        '\tbound:Connect with a signer app\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('regen refused'));
      expect(res.stderr, contains('key no longer exists'));
      expect(
        manifest.readAsStringSync(),
        contains('authConnectSignerApp'),
      );
    });

    test('pure rename with unchanged value re-binds without a refusal', () {
      writeArb({'authConnectSigner': 'Connect with a signer app'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: Connect with a signer app\n',
      );
      writeManifest(
        'authConnectSignerApp\te2e/maestro/asserts/menu.yaml'
        '\tbound:Connect with a signer app\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('1 added, 1 removed'));
      expect(
        manifest.readAsStringSync(),
        contains('authConnectSigner\te2e/maestro/asserts/menu.yaml'),
      );
    });

    test('rendered bindings fail when the ARB template changes', () {
      writeArb({'profileVideoThumbnailLabel': 'Clip {number}'});
      writeFlow('tests/searchTags.yaml', '- tapOn: Video thumbnail 1\n');
      writeManifest(
        'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
        '\trendered:Video thumbnail 1\n',
      );

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stderr, contains('ARB template'));
      expect(res.stderr, contains('Clip {number}'));
    });

    test('base-ref ratchet fails when a branch erodes a base binding', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      expect(
        Process.runSync('git', [
          'init',
          '-b',
          'main',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          '-c',
          'user.name=test',
          '-c',
          'user.email=test@example.com',
          'commit',
          '-m',
          'base',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          'switch',
          '-c',
          'branch',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );

      writeManifest('# branch regenerated the binding away\n');

      final res = run(baseRef: 'main', allowNoBase: false);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('ERODED'));
    });
  });
}
