import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/build_provenance_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('BuildProvenanceService', () {
    test('formats a release build with installed Shorebird patch', () async {
      final provenance = await _service(
        buildMode: BuildMode.release,
        installSource: InstallSource.playStore,
        shorebirdAvailable: true,
        readPatchNumber: () async => 3,
      ).resolve();

      expect(
        provenance.summary,
        '[BUILD] 1.0.20+837 · release · env=production · android · '
        'install=playStore · shorebird=available · patch=3',
      );
      expect(provenance.buildTag, '1.0.20+837');
      expect(provenance.patchLabel, '3');
    });

    test('formats each build mode', () async {
      for (final buildMode in BuildMode.values) {
        final provenance = await _service(buildMode: buildMode).resolve();

        expect(provenance.summary, contains(' · ${buildMode.name} · '));
      }
    });

    test('formats each install source', () async {
      for (final installSource in InstallSource.values) {
        final provenance = await _service(
          installSource: installSource,
        ).resolve();

        expect(provenance.summary, contains('install=${installSource.name}'));
      }
    });

    test('reports available Shorebird with no installed patch', () async {
      final provenance = await _service(
        shorebirdAvailable: true,
        readPatchNumber: () async => null,
      ).resolve();

      expect(provenance.summary, contains('shorebird=available · patch=none'));
      expect(provenance.patchStatus, ShorebirdPatchStatus.none);
    });

    test('reports unavailable Shorebird without reading patch state', () async {
      var didReadPatch = false;

      final provenance = await _service(
        readPatchNumber: () async {
          didReadPatch = true;
          return 7;
        },
      ).resolve();

      expect(didReadPatch, isFalse);
      expect(
        provenance.summary,
        contains('shorebird=unavailable · patch=unavailable'),
      );
      expect(provenance.patchStatus, ShorebirdPatchStatus.unavailable);
    });

    test('degrades patch read failures to unknown', () async {
      final provenance = await _service(
        shorebirdAvailable: true,
        readPatchNumber: () async => throw StateError('ffi unavailable'),
      ).resolve();

      expect(
        provenance.summary,
        contains('shorebird=available · patch=unknown'),
      );
      expect(provenance.patchStatus, ShorebirdPatchStatus.unknown);
    });

    test('does not expose identifier-shaped values in summary', () async {
      final provenance = await _service(
        shorebirdAvailable: true,
        readPatchNumber: () async => 12,
      ).resolve();

      expect(provenance.summary, isNot(contains('app_id')));
      expect(provenance.summary, isNot(contains('pubkey')));
      expect(provenance.summary, isNot(contains('npub')));
      expect(
        provenance.summary,
        isNot(matches(RegExp('[0-9a-fA-F]{32,}'))),
      );
    });
  });
}

BuildProvenanceService _service({
  BuildMode buildMode = BuildMode.debug,
  InstallSource installSource = InstallSource.sideload,
  bool shorebirdAvailable = false,
  ShorebirdPatchReader? readPatchNumber,
}) {
  return BuildProvenanceService(
    packageInfo: PackageInfo(
      appName: 'Divine',
      packageName: 'com.divinevideo.app',
      version: '1.0.20',
      buildNumber: '837',
    ),
    installSource: installSource,
    environment: AppEnvironment.production,
    platform: 'android',
    shorebirdAvailable: shorebirdAvailable,
    buildMode: buildMode,
    readPatchNumber: readPatchNumber,
  );
}
