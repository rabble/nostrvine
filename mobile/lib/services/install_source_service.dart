// ABOUTME: Resolves how the app was installed (Play Store, App Store,
// ABOUTME: TestFlight, Zapstore, sideload) via a native method channel.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Method-channel-backed implementation.
///
/// Android: queries the installer package name
/// (`com.android.vending` → Play Store, `com.zapstore.app` → Zapstore).
/// iOS: inspects the app-store receipt URL (`sandboxReceipt` → TestFlight).
/// On web/desktop/unsupported platforms it returns [InstallSource.sideload].
class InstallSourceService {
  const InstallSourceService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'divine/install_source';

  final MethodChannel _channel;

  Future<InstallSource> resolve() async {
    // Web and desktop builds have no native install-referrer channel.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return InstallSource.sideload;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final installer = await _channel.invokeMethod<String>(
          'getInstallerPackageName',
        );
        return resolveAndroidInstallSource(installer);
      }
      // iOS.
      final isSandbox = await _channel.invokeMethod<bool>('isSandboxReceipt');
      if (isSandbox == null) {
        Log.warning(
          'Install source channel returned no iOS receipt environment; '
          'falling back to sideload',
          name: 'InstallSourceService',
          category: LogCategory.system,
        );
        return InstallSource.sideload;
      }
      return resolveIosInstallSource(isSandbox: isSandbox);
    } on PlatformException catch (e) {
      // A missing channel (e.g. an older native shell) or a revoked installer
      // permission must never block app launch — fall back to sideload and let
      // the in-app review gate (which only matches Play/App Store) no-op.
      Log.warning(
        'Install source resolution failed: ${e.code}',
        name: 'InstallSourceService',
        category: LogCategory.system,
      );
      return InstallSource.sideload;
    } on MissingPluginException catch (e) {
      Log.warning(
        'Install source channel missing; falling back to sideload: $e',
        name: 'InstallSourceService',
        category: LogCategory.system,
      );
      return InstallSource.sideload;
    }
  }
}
