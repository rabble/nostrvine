// ABOUTME: Formats startup build provenance for release QA and crash triage.
// ABOUTME: Keeps Shorebird patch inspection best-effort and non-fatal.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef ShorebirdPatchReader = Future<int?> Function();

enum BuildMode {
  debug,
  profile,
  release;

  static BuildMode get current {
    if (kDebugMode) return BuildMode.debug;
    if (kProfileMode) return BuildMode.profile;
    return BuildMode.release;
  }
}

enum ShorebirdPatchStatus { unavailable, none, installed, unknown }

@immutable
class BuildProvenance {
  const BuildProvenance({
    required this.version,
    required this.buildNumber,
    required this.buildMode,
    required this.environment,
    required this.platform,
    required this.installSource,
    required this.shorebirdAvailable,
    required this.patchStatus,
    this.patchNumber,
  });

  final String version;
  final String buildNumber;
  final BuildMode buildMode;
  final AppEnvironment environment;
  final String platform;
  final InstallSource installSource;
  final bool shorebirdAvailable;
  final ShorebirdPatchStatus patchStatus;
  final int? patchNumber;

  String get buildTag => '$version+$buildNumber';

  String get shorebirdStatus =>
      shorebirdAvailable ? 'available' : 'unavailable';

  String get patchLabel {
    return switch (patchStatus) {
      ShorebirdPatchStatus.unavailable => 'unavailable',
      ShorebirdPatchStatus.none => 'none',
      ShorebirdPatchStatus.installed => '${patchNumber ?? 'unknown'}',
      ShorebirdPatchStatus.unknown => 'unknown',
    };
  }

  String get summary =>
      '[BUILD] $buildTag · ${buildMode.name} · env=${environment.name} · '
      '$platform · install=${installSource.name} · '
      'shorebird=$shorebirdStatus · patch=$patchLabel';
}

class BuildProvenanceService {
  const BuildProvenanceService({
    required this.packageInfo,
    required this.installSource,
    required this.environment,
    required this.platform,
    required this.shorebirdAvailable,
    this.buildMode = BuildMode.release,
    this.readPatchNumber,
  });

  final PackageInfo packageInfo;
  final InstallSource installSource;
  final AppEnvironment environment;
  final String platform;
  final bool shorebirdAvailable;
  final BuildMode buildMode;
  final ShorebirdPatchReader? readPatchNumber;

  Future<BuildProvenance> resolve() async {
    if (!shorebirdAvailable || readPatchNumber == null) {
      return _provenance(patchStatus: ShorebirdPatchStatus.unavailable);
    }

    try {
      final patchNumber = await readPatchNumber!();
      if (patchNumber == null) {
        return _provenance(patchStatus: ShorebirdPatchStatus.none);
      }
      return _provenance(
        patchStatus: ShorebirdPatchStatus.installed,
        patchNumber: patchNumber,
      );
    } catch (_) {
      return _provenance(patchStatus: ShorebirdPatchStatus.unknown);
    }
  }

  BuildProvenance _provenance({
    required ShorebirdPatchStatus patchStatus,
    int? patchNumber,
  }) {
    return BuildProvenance(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      buildMode: buildMode,
      environment: environment,
      platform: platform,
      installSource: installSource,
      shorebirdAvailable: shorebirdAvailable,
      patchStatus: patchStatus,
      patchNumber: patchNumber,
    );
  }
}
