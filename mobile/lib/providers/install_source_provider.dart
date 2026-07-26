// ABOUTME: Riverpod provider for the device's resolved [InstallSource].
// ABOUTME: Resolved once at startup and overridden in DeviceScope so every
// ABOUTME: account container shares the same cheap read.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [InstallSource] for this device install, resolved once during startup
/// (see `main.dart`) and injected into every account container via
/// [DeviceScope.overrides].
///
/// Throws by default; `main.dart` overrides it with the value resolved by
/// [InstallSourceService] before `runApp`. Reading it before that is a
/// programmer error, not a runtime condition to handle.
final installSourceProvider = Provider<InstallSource>(
  (ref) => throw StateError(
    'installSourceProvider must be overridden at container creation',
  ),
);
